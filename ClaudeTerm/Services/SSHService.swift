import Foundation
import Citadel
import Crypto
import NIOCore
import NIOPosix
import NIOSSH
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

    /// The TTYStdinWriter captured from within the withPTY closure.
    /// Used by sendInput/executeCommand/resizeTerminal from outside the closure.
    private var stdinWriter: TTYStdinWriter?

    /// The long-lived Task that runs the withPTY closure.
    private var sessionTask: Task<Void, Never>?

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
            // Build authentication method
            let authMethod: SSHAuthenticationMethod
            switch connection.authMethod {
            case .password:
                guard let password = password, !password.isEmpty else {
                    throw SSHError.missingCredentials("No password provided")
                }
                authMethod = .passwordBased(username: connection.username, password: password)

            case .privateKey(let keyPath):
                let keyString = try loadPrivateKey(from: keyPath)
                authMethod = try buildKeyAuthMethod(username: connection.username, keyString: keyString, keyPath: keyPath)
            }

            // Create SSH client using the correct Citadel API
            let client = try await SSHClient.connect(
                host: connection.host,
                port: Int(connection.port),
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never,
                algorithms: .all,
                group: .singleton
            )

            self.client = client

            // Use a continuation to signal when the PTY session is ready
            // (i.e., when we have captured the stdinWriter).
            // The readyContinuation is stored in an actor-isolated box to
            // avoid data races between the spawned Task and the continuation body.
            let readyBox = ReadyContinuationBox()

            self.sessionTask = Task { [weak self] in
                guard let self = self else {
                    await readyBox.resume(throwing: SSHError.serviceDeallocated)
                    return
                }

                do {
                    let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                        wantReply: true,
                        term: "xterm-256color",
                        terminalCharacterWidth: 80,
                        terminalRowHeight: 24,
                        terminalPixelWidth: 0,
                        terminalPixelHeight: 0,
                        terminalModes: SSHTerminalModes([:])
                    )

                    try await client.withPTY(ptyRequest) { [weak self] inbound, outbound in
                        guard let self = self else { return }

                        // Store the writer so external callers can use it
                        self.stdinWriter = outbound

                        // Signal that the PTY session is ready
                        await readyBox.resume()

                        // Read output from the TTY and publish it
                        for try await output in inbound {
                            switch output {
                            case .stdout(let buffer):
                                let text = String(buffer: buffer)
                                await MainActor.run {
                                    self.outputSubject.send(text)
                                }
                            case .stderr(let buffer):
                                let text = String(buffer: buffer)
                                await MainActor.run {
                                    self.outputSubject.send(text)
                                }
                            }
                        }
                    }

                    // withPTY returned normally -- session ended
                    await MainActor.run {
                        self.stdinWriter = nil
                        self.isConnected = false
                        self.connectionState = .disconnected
                        self.connectionStateSubject.send(.disconnected)
                        self.outputSubject.send("\nConnection closed\n")
                    }
                } catch {
                    // If we haven't signaled readiness yet, propagate the error
                    await readyBox.resume(throwing: error)

                    await MainActor.run {
                        self.stdinWriter = nil
                        self.isConnected = false
                        self.connectionState = .disconnected
                        self.connectionStateSubject.send(.disconnected)
                        self.outputSubject.send("\nConnection closed: \(error.localizedDescription)\n")
                    }
                }
            }

            // Wait until the PTY session is established or fails
            try await readyBox.wait()

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
        // Cancel the session task (this will cause the withPTY closure to end)
        sessionTask?.cancel()
        sessionTask = nil
        stdinWriter = nil

        // Close the SSH client
        if let client = client {
            Task {
                try? await client.close()
            }
        }
        client = nil

        isConnected = false
        connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
        outputSubject.send("\nDisconnected\n")
    }

    // MARK: - I/O Operations

    func executeCommand(_ command: String) {
        guard isConnected, let writer = stdinWriter else { return }

        let commandWithNewline = command + "\n"
        Task {
            do {
                try await writer.write(ByteBuffer(string: commandWithNewline))
            } catch {
                outputSubject.send("\nError sending command: \(error.localizedDescription)\n")
            }
        }
    }

    func sendInput(_ input: String) {
        guard isConnected, let writer = stdinWriter else { return }

        Task {
            do {
                try await writer.write(ByteBuffer(string: input))
            } catch {
                outputSubject.send("\nError sending input: \(error.localizedDescription)\n")
            }
        }
    }

    func resizeTerminal(columns: Int, rows: Int) {
        guard isConnected, let writer = stdinWriter else { return }

        Task {
            do {
                try await writer.changeSize(
                    cols: columns,
                    rows: rows,
                    pixelWidth: 0,
                    pixelHeight: 0
                )
            } catch {
                print("Failed to resize terminal: \(error)")
            }
        }
    }

    // MARK: - Private Methods

    /// Build an SSHAuthenticationMethod from a private key string.
    /// Detects key type from the OpenSSH private key format and creates
    /// the appropriate authentication method.
    private func buildKeyAuthMethod(username: String, keyString: String, keyPath: String) throws -> SSHAuthenticationMethod {
        // Try to get passphrase from keychain
        let passphrase: String? = try? KeychainService.shared.getPassword(
            for: "ssh_key_\(keyPath)",
            server: "key_passphrase"
        )

        // Detect the key type by parsing the OpenSSH private key header
        let keyType: SSHKeyType
        do {
            keyType = try SSHKeyDetection.detectPrivateKeyType(from: keyString)
        } catch {
            throw SSHError.authenticationFailed("Could not detect key type: \(error.localizedDescription)")
        }

        let decryptionKey = passphrase?.data(using: .utf8)

        switch keyType {
        case .ed25519:
            // Uses Citadel's public convenience init on Curve25519.Signing.PrivateKey
            let privateKey = try Curve25519.Signing.PrivateKey(
                sshEd25519: keyString,
                decryptionKey: decryptionKey
            )
            return .ed25519(username: username, privateKey: privateKey)

        case .rsa:
            // Uses Citadel's public convenience init on Insecure.RSA.PrivateKey
            let privateKey = try Insecure.RSA.PrivateKey(
                sshRsa: keyString,
                decryptionKey: decryptionKey
            )
            return .rsa(username: username, privateKey: privateKey)

        default:
            throw SSHError.authenticationFailed("Unsupported key type: \(keyType). Only ED25519 and RSA keys are currently supported.")
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

// MARK: - Ready Continuation Box
/// An actor that safely bridges between a spawned Task signaling readiness
/// and the caller waiting for that signal. Ensures exactly-once resume semantics.
/// Handles the case where resume() is called before wait() by storing the result.
private actor ReadyContinuationBox {
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?

    /// Called by the spawning side to wait for readiness or an error.
    /// If resume was already called, returns immediately with the stored result.
    func wait() async throws {
        // If already resolved before wait() was called, return immediately
        if let result = self.result {
            return try result.get()
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            // Double-check in case resume was called between the if-check and here
            if let result = self.result {
                switch result {
                case .success:
                    cont.resume()
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            } else {
                self.continuation = cont
            }
        }
    }

    /// Signal success (PTY is ready).
    func resume() {
        guard result == nil else { return }
        result = .success(())
        continuation?.resume()
        continuation = nil
    }

    /// Signal failure.
    func resume(throwing error: Error) {
        guard result == nil else { return }
        result = .failure(error)
        continuation?.resume(throwing: error)
        continuation = nil
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
