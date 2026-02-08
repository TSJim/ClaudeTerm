import Foundation
import Combine
import NMSSH

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

// MARK: - Real SSH Service using NMSSH
class SSHService: ObservableObject, SSHServiceProtocol {
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var isConnected: Bool = false

    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let outputSubject = PassthroughSubject<String, Never>()

    private var session: NMSSHSession?
    private var channel: NMSSHChannel?
    private var outputQueue: DispatchQueue?

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

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SSHError.serviceDeallocated)
                    return
                }

                do {
                    // Create SSH session
                    let session = NMSSHSession(host: connection.host, port: Int32(connection.port), andUsername: connection.username)
                    self.session = session

                    // Connect to server
                    session.connect()

                    guard session.isConnected else {
                        throw SSHError.connectionFailed("Could not connect to \(connection.host)")
                    }

                    // Authenticate based on method
                    switch connection.authMethod {
                    case .password:
                        guard let password = password, !password.isEmpty else {
                            throw SSHError.missingCredentials("No password provided")
                        }
                        session.authenticate(byPassword: password)

                    case .privateKey(let keyPath):
                        // Load private key from file system or secure storage
                        let privateKey = try loadPrivateKey(from: keyPath)

                        // Try to get passphrase from keychain if key is encrypted
                        let passphrase = try? KeychainService.shared.getPassword(
                            for: "ssh_key_\(keyPath)",
                            server: "key_passphrase"
                        )

                        // Load public key if it exists (optional for many servers)
                        let publicKey = try? loadPublicKey(from: keyPath)

                        session.authenticateBy(inMemoryPublicKey: publicKey,
                                               privateKey: privateKey,
                                               andPassword: passphrase)
                    }

                    guard session.isAuthorized else {
                        throw SSHError.authenticationFailed("Invalid credentials")
                    }

                    // Open shell channel with PTY
                    let channel = session.channel
                    channel.requestPty = true
                    channel.ptyTerminalType = NMSSHChannelPtyTerminal.xterm

                    // Set up output callback
                    channel.delegate = self

                    try channel.startShell()

                    self.channel = channel

                    // Set up output reading queue
                    self.outputQueue = DispatchQueue(label: "com.claudeterm.ssh-output", qos: .userInitiated)
                    self.startReadingOutput()

                    DispatchQueue.main.async {
                        self.isConnected = true
                        self.connectionState = .connected
                        self.connectionStateSubject.send(.connected)
                        self.outputSubject.send("Connected to \(connection.host)\n")
                    }

                    continuation.resume()

                } catch {
                    DispatchQueue.main.async {
                        self.connectionState = .error(error.localizedDescription)
                        self.connectionStateSubject.send(.error(error.localizedDescription))
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func disconnect() {
        outputQueue?.suspend()
        outputQueue = nil

        channel?.closeShell()
        channel = nil

        session?.disconnect()
        session = nil

        isConnected = false
        connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
        outputSubject.send("\nDisconnected\n")
    }

    // MARK: - I/O Operations

    func executeCommand(_ command: String) {
        guard isConnected, let channel = channel else { return }

        let commandWithNewline = command + "\n"
        if let data = commandWithNewline.data(using: .utf8) {
            channel.write(data as Data)
        }
    }

    func sendInput(_ input: String) {
        guard isConnected, let channel = channel else { return }

        if let data = input.data(using: .utf8) {
            channel.write(data as Data)
        }
    }

    func resizeTerminal(columns: Int, rows: Int) {
        guard isConnected, let channel = channel else { return }

        // Use NMSSH's built-in PTY resize method
        // This sends the proper SSH protocol message to resize the terminal
        channel.requestSizeWidth(Int32(columns), height: Int32(rows))
    }

    // MARK: - Private Methods

    private func loadPrivateKey(from path: String) throws -> String {
        // First try to load from app's document directory
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
    
    private func loadPublicKey(from privateKeyPath: String) throws -> String {
        // Public key is typically private key path + ".pub"
        let publicKeyPath = privateKeyPath + ".pub"
        let fileManager = FileManager.default
        
        // Try absolute path first
        if publicKeyPath.hasPrefix("/") && fileManager.fileExists(atPath: publicKeyPath) {
            guard let data = fileManager.contents(atPath: publicKeyPath),
                  let key = String(data: data, encoding: .utf8) else {
                throw SSHError.missingCredentials("Could not read public key")
            }
            return key
        }
        
        // Try documents directory
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let keyURL = documentsPath.appendingPathComponent(publicKeyPath)
            guard fileManager.fileExists(atPath: keyURL.path) else {
                // Public key is optional, return empty string if not found
                return ""
            }
            guard let data = fileManager.contents(atPath: keyURL.path),
                  let key = String(data: data, encoding: .utf8) else {
                return ""
            }
            return key
        }
        
        return ""
    }

    private func startReadingOutput() {
        guard let channel = channel else { return }

        outputQueue?.async { [weak self] in
            while let self = self, self.isConnected {
                do {
                    // Read available data (non-blocking)
                    let data = try channel.readData(1000)
                    if let data = data as Data?, !data.isEmpty {
                        if let output = String(data: data, encoding: .utf8) {
                            DispatchQueue.main.async {
                                self.outputSubject.send(output)
                            }
                        }
                    }
                    // Small delay to prevent tight loop
                    Thread.sleep(forTimeInterval: 0.01)
                } catch {
                    // Channel closed or error
                    break
                }
            }
        }
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

// MARK: - NMSSHChannel Delegate
extension SSHService: NMSSHChannelDelegate {
    func channel(_ channel: NMSSHChannel!, didReadData data: String!) {
        if let data = data {
            outputSubject.send(data)
        }
    }

    func channel(_ channel: NMSSHChannel!, didReadError error: String!) {
        if let error = error {
            outputSubject.send(error)
        }
    }

    func channelShell(_ channel: NMSSHChannel!, didCloseWithError error: Error!) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.connectionState = .disconnected
            self?.connectionStateSubject.send(.disconnected)
        }
    }
}
