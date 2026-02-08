import Foundation
import Citadel
import NIOCore
import NIOPosix
import Combine

// MARK: - SSH Service Protocol
protocol SSHServiceProtocol {
    var isConnected: Bool { get }
    var connectionState: ConnectionState { get }
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }
    var outputPublisher: AnyPublisher<String, Never> { get }
    
    func connect(to connection: SSHConnection, password: String?) async throws
    func disconnect()
    func executeCommand(_ command: String)
    func sendInput(_ input: String)
    func resizeTerminal(columns: Int, rows: Int)
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

// MARK: - Real SSH Service using Citadel
class SSHService: ObservableObject, SSHServiceProtocol {
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var isConnected: Bool = false
    
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let outputSubject = PassthroughSubject<String, Never>()
    
    private var client: SSHClient?
    private var shellChannel: SSHShellChannel?
    private var eventLoopGroup: EventLoopGroup?
    private var outputTask: Task<Void, Never>?
    
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    var outputPublisher: AnyPublisher<String, Never> {
        outputSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Connection
    
    func connect(to connection: SSHConnection, password: String?) async throws {
        await MainActor.run {
            connectionState = .connecting
            connectionStateSubject.send(.connecting)
        }
        
        do {
            // Create event loop group
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.eventLoopGroup = eventLoopGroup
            
            // Build authentication method
            let authMethod: SSHAuthenticationMethod
            switch connection.authMethod {
            case .password:
                guard let password = password, !password.isEmpty else {
                    throw SSHError.missingCredentials("No password provided")
                }
                authMethod = .password(.init(username: connection.username, password: password))
                
            case .privateKey(let keyPath):
                // Load private key from file
                let privateKey = try loadPrivateKey(from: keyPath)
                // Try to get passphrase from keychain
                let passphrase = try? KeychainService.shared.getPassword(
                    for: "ssh_key_\(keyPath)",
                    server: "key_passphrase"
                )
                
                // Citadel uses NIOSSH for key handling
                // For now, use password-based or try agent-based auth
                // Full key auth would need more implementation
                if let passphrase = passphrase {
                    authMethod = .privateKey(.init(
                        username: connection.username,
                        privateKey: privateKey.data(using: .utf8)!,
                        passphrase: passphrase
                    ))
                } else {
                    authMethod = .privateKey(.init(
                        username: connection.username,
                        privateKey: privateKey.data(using: .utf8)!
                    ))
                }
            }
            
            // Create SSH client
            let client = try await SSHClient.connect(
                host: connection.host,
                port: Int(connection.port),
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(), // TODO: Implement proper host key validation
                eventLoopGroup: eventLoopGroup
            )
            
            self.client = client
            
            // Create shell channel with PTY
            let shellChannel = try await client.openShellChannel()
            self.shellChannel = shellChannel
            
            // Start reading output
            startReadingOutput(from: shellChannel)
            
            await MainActor.run {
                self.isConnected = true
                self.connectionState = .connected
                self.connectionStateSubject.send(.connected)
                self.outputSubject.send("Connected to \(connection.host)\n")
            }
            
        } catch {
            await MainActor.run {
                let errorMessage = "Connection failed: \(error.localizedDescription)"
                self.connectionState = .error(errorMessage)
                self.connectionStateSubject.send(.error(errorMessage))
            }
            throw error
        }
    }
    
    func disconnect() {
        outputTask?.cancel()
        outputTask = nil
        
        // Close shell channel
        if let shellChannel = shellChannel {
            Task {
                try? await shellChannel.close()
            }
        }
        shellChannel = nil
        
        // Disconnect client
        if let client = client {
            Task {
                try? await client.close()
            }
        }
        client = nil
        
        // Shutdown event loop
        if let eventLoopGroup = eventLoopGroup {
            Task {
                try? await eventLoopGroup.shutdownGracefully()
            }
        }
        eventLoopGroup = nil
        
        isConnected = false
        connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
        outputSubject.send("\nDisconnected\n")
    }
    
    // MARK: - I/O Operations
    
    func executeCommand(_ command: String) {
        guard isConnected, let shellChannel = shellChannel else { return }
        
        let commandWithNewline = command + "\n"
        Task {
            do {
                try await shellChannel.write(commandWithNewline)
            } catch {
                outputSubject.send("\nError sending command: \(error.localizedDescription)\n")
            }
        }
    }
    
    func sendInput(_ input: String) {
        guard isConnected, let shellChannel = shellChannel else { return }
        
        Task {
            do {
                try await shellChannel.write(input)
            } catch {
                outputSubject.send("\nError sending input: \(error.localizedDescription)\n")
            }
        }
    }
    
    func resizeTerminal(columns: Int, rows: Int) {
        guard isConnected, let shellChannel = shellChannel else { return }
        
        Task {
            do {
                try await shellChannel.setTerminalSize(width: UInt16(columns), height: UInt16(rows))
            } catch {
                print("Failed to resize terminal: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startReadingOutput(from channel: SSHShellChannel) {
        outputTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                for try await output in channel {
                    let outputString = String(buffer: output)
                    await MainActor.run {
                        self.outputSubject.send(outputString)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.connectionState = .disconnected
                    self.connectionStateSubject.send(.disconnected)
                    self.outputSubject.send("\nConnection closed\n")
                }
            }
        }
    }
    
    private func loadPrivateKey(from path: String) throws -> String {
        let fileManager = FileManager.default
        
        // Check if it's an absolute path
        if path.hasPrefix("/") {
            guard fileManager.fileExists(atPath: path) else {
                throw SSHError.missingCredentials("Private key not found at \(path)")
            }
            guard let data = fileManager.contents(atPath: path),
                  let key = String(data: data, encoding: .utf8) else {
                throw SSHError.missingCredentials("Could not read private key")
            }
            return key
        }
        
        // Try loading from app's documents directory
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let keyURL = documentsPath.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: keyURL.path) else {
                throw SSHError.missingCredentials("Private key not found: \(path)")
            }
            guard let data = fileManager.contents(atPath: keyURL.path),
                  let key = String(data: data, encoding: .utf8) else {
                throw SSHError.missingCredentials("Could not read private key")
            }
            return key
        }
        
        throw SSHError.missingCredentials("Could not locate private key: \(path)")
    }
}

// MARK: - SSH Errors
enum SSHError: Error, LocalizedError {
    case serviceDeallocated
    case connectionFailed(String)
    case authenticationFailed(String)
    case missingCredentials(String)
    case channelError(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceDeallocated:
            return "SSH service was deallocated"
        case .connectionFailed(let msg):
            return "Connection failed: \(msg)"
        case .authenticationFailed(let msg):
            return "Authentication failed: \(msg)"
        case .missingCredentials(let msg):
            return "Missing credentials: \(msg)"
        case .channelError(let msg):
            return "Channel error: \(msg)"
        }
    }
}
