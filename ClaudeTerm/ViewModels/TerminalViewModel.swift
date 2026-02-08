import Foundation
import Combine

class TerminalViewModel: ObservableObject {
    let session: TerminalSession
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isInMultiplexerSession = false
    @Published var shouldUseMultiplexer = true
    @Published var lastError: String? = nil
    
    private var terminalFeeder: TerminalEmulatorViewModel?
    private let sshService: SSHServiceProtocol
    private let multiplexerManager: MultiplexerManager
    private let persistenceManager = BackgroundPersistenceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Whether to automatically reconnect when returning from background
    var autoReconnectEnabled = true
    
    init(session: TerminalSession, 
         sshService: SSHServiceProtocol = SSHService(),
         multiplexerType: MultiplexerManager.MultiplexerType = .tmux) {
        self.session = session
        self.sshService = sshService
        self.multiplexerManager = MultiplexerManager(type: multiplexerType)
        setupBindings()
        setupLifecycleObservers()
    }
    
    func setTerminalFeeder(_ feeder: TerminalEmulatorViewModel) {
        self.terminalFeeder = feeder
    }
    
    private func setupBindings() {
        sshService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                // Surface errors from connection state
                if case .error(let message) = state {
                    self?.lastError = message
                }
            }
            .store(in: &cancellables)
        
        // Feed SSH output incrementally to SwiftTerm instead of accumulating
        sshService.outputPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                // Feed only the new output to SwiftTerm incrementally
                self?.terminalFeeder?.feed(output)
            }
            .store(in: &cancellables)
    }
    
    private func setupLifecycleObservers() {
        // Listen for background/foreground notifications
        NotificationCenter.default.publisher(for: .terminalWillEnterBackground)
            .sink { [weak self] _ in
                self?.handleWillEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .terminalDidEnterForeground)
            .sink { [weak self] notification in
                let shouldReconnect = notification.userInfo?["shouldAutoReconnect"] as? Bool ?? false
                self?.handleDidEnterForeground(shouldAutoReconnect: shouldReconnect)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Connection Management
    
    func connect(useMultiplexer: Bool = true) {
        self.shouldUseMultiplexer = useMultiplexer
        clearError()
        
        Task {
            do {
                // Fetch password from Keychain if needed
                var password: String? = nil
                if case .password = session.connection.authMethod {
                    password = try? KeychainService.shared.getPassword(
                        for: session.connection.username,
                        server: "\(session.connection.host):\(session.connection.port)"
                    )
                }
                
                try await sshService.connect(to: session.connection, password: password)
                
                // If using multiplexer, attach to or create session
                if useMultiplexer {
                    await MainActor.run {
                        self.terminalFeeder?.feed("\n[Attaching to persistent session...]\n")
                    }
                    let attachCommand = multiplexerManager.startClaudeInSession(
                        connectionName: session.connection.name,
                        resume: false
                    )
                    sshService.executeCommand(attachCommand)
                    isInMultiplexerSession = true
                }
            } catch let error as SSHError {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    self.lastError = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func disconnect() {
        // If in multiplexer, detach gracefully
        if isInMultiplexerSession {
            let commands = multiplexerManager.prepareForBackgroundCommands()
            for command in commands {
                sshService.sendInput(command)
            }
            // Give it a moment to detach before closing connection
            Thread.sleep(forTimeInterval: 0.5)
        }
        sshService.disconnect()
        isInMultiplexerSession = false
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        lastError = nil
    }
    
    // MARK: - Background/Foreground Handling
    
    private func handleWillEnterBackground() {
        guard connectionState == .connected else { return }
        
        // Save session state
        let state = PersistedSessionState(
            sessionId: session.id,
            connectionId: session.connection.id,
            lastCommand: nil,
            scrollbackBuffer: "", // No longer storing entire buffer
            timestamp: Date(),
            wasRunningTmux: isInMultiplexerSession
        )
        SessionStateStore.shared.saveState(state)
        
        if shouldUseMultiplexer && isInMultiplexerSession {
            // Send detach command to tmux/screen
            let commands = multiplexerManager.prepareForBackgroundCommands()
            for command in commands {
                sshService.sendInput(command)
            }
            terminalFeeder?.feed("\n[Session detached - running in background on server]\n")
        } else {
            // No multiplexer - connection will drop
            terminalFeeder?.feed("\n[App backgrounded - connection will close]\n")
            disconnect()
        }
    }
    
    private func handleDidEnterForeground(shouldAutoReconnect: Bool) {
        guard autoReconnectEnabled else { return }
        
        if shouldUseMultiplexer {
            if connectionState != .connected {
                // Reconnect and reattach
                terminalFeeder?.feed("\n[Reconnecting to session...]\n")
                connect(useMultiplexer: true)
            } else {
                // Still connected, just reattach to multiplexer
                let commands = multiplexerManager.prepareForForegroundCommands(
                    connectionName: session.connection.name
                )
                for command in commands {
                    sshService.executeCommand(command)
                }
            }
        } else if shouldAutoReconnect && connectionState != .connected {
            // Try to reconnect if within time window
            terminalFeeder?.feed("\n[Auto-reconnecting...]\n")
            connect(useMultiplexer: false)
        }
        
        // Clean up old persisted states
        SessionStateStore.shared.clearOldStates()
    }
    
    // MARK: - Commands
    
    func sendCommand(_ command: String) {
        sshService.executeCommand(command)
    }
    
    func sendInput(_ input: String) {
        sshService.sendInput(input + "\n")
    }
    
    func sendRawInput(_ input: String) {
        // For special keys (Ctrl+A, etc.)
        sshService.sendInput(input)
    }
    
    func resizeTerminal(columns: Int, rows: Int) {
        sshService.resizeTerminal(columns: columns, rows: rows)
    }

    func clearTerminal() {
        terminalFeeder?.clear()
    }
    
    /// Start Claude Code in a persistent tmux/screen session
    func startClaudeInPersistentSession(resume: Bool = false) {
        let command = multiplexerManager.startClaudeInSession(
            connectionName: session.connection.name,
            resume: resume
        )
        sshService.executeCommand(command)
        isInMultiplexerSession = true
    }
    
    /// Detach from current multiplexer session (keeps it running on server)
    func detachFromSession() {
        guard isInMultiplexerSession else { return }
        let commands = multiplexerManager.prepareForBackgroundCommands()
        for command in commands {
            sendRawInput(command)
        }
        isInMultiplexerSession = false
    }
}
