import Foundation
import Combine

class ConnectionListViewModel: ObservableObject {
    @Published var connections: [SSHConnection] = []
    @Published var recentSessions: [TerminalSession] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadConnections()
    }
    
    func addConnection(_ connection: SSHConnection) {
        connections.append(connection)
        saveConnections()
    }
    
    func deleteConnection(_ connection: SSHConnection) {
        connections.removeAll { $0.id == connection.id }
        saveConnections()
    }
    
    func createSession(for connection: SSHConnection) -> TerminalSession {
        let session = TerminalSession(connection: connection, title: connection.name)
        recentSessions.append(session)
        // Keep only last 10 sessions
        if recentSessions.count > 10 {
            recentSessions.removeFirst()
        }
        return session
    }
    
    private func loadConnections() {
        // TODO: Load from UserDefaults or Keychain
        // For now, use mock data
        #if DEBUG
        connections = [
            SSHConnection(
                name: "Dev Server",
                host: "dev.example.com",
                username: "developer",
                authMethod: .password
            )
        ]
        #endif
    }
    
    private func saveConnections() {
        // TODO: Persist to UserDefaults/Keychain
    }
}
