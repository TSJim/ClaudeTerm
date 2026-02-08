import Foundation
import Combine

class ConnectionListViewModel: ObservableObject {
    @Published var connections: [SSHConnection] = []
    @Published var recentSessions: [TerminalSession] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let connectionsKey = "savedSSHConnections"
    private let sessionsKey = "recentTerminalSessions"
    
    init() {
        loadConnections()
        loadRecentSessions()
    }
    
    func addConnection(_ connection: SSHConnection) {
        // Check for duplicates by ID
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        saveConnections()
    }
    
    func deleteConnection(_ connection: SSHConnection) {
        connections.removeAll { $0.id == connection.id }
        saveConnections()
        
        // Also clear any password for this connection
        try? KeychainService.shared.deletePassword(
            for: connection.username,
            server: "\(connection.host):\(connection.port)"
        )
    }
    
    func updateConnection(_ connection: SSHConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
            saveConnections()
        }
    }
    
    func createSession(for connection: SSHConnection) -> TerminalSession {
        let session = TerminalSession(connection: connection, title: connection.name)
        recentSessions.append(session)
        // Keep only last 10 sessions
        if recentSessions.count > 10 {
            recentSessions.removeFirst()
        }
        saveRecentSessions()
        return session
    }
    
    func clearRecentSessions() {
        recentSessions.removeAll()
        UserDefaults.standard.removeObject(forKey: sessionsKey)
    }
    
    // MARK: - Persistence
    
    private func loadConnections() {
        guard let data = UserDefaults.standard.data(forKey: connectionsKey) else {
            #if DEBUG
            // Add mock data for development
            connections = [
                SSHConnection(
                    name: "Dev Server",
                    host: "dev.example.com",
                    username: "developer",
                    authMethod: .password
                )
            ]
            #endif
            return
        }
        
        do {
            connections = try JSONDecoder().decode([SSHConnection].self, from: data)
        } catch {
            print("Failed to load connections: \(error)")
            connections = []
        }
    }
    
    private func saveConnections() {
        do {
            let data = try JSONEncoder().encode(connections)
            UserDefaults.standard.set(data, forKey: connectionsKey)
        } catch {
            print("Failed to save connections: \(error)")
        }
    }
    
    private func loadRecentSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else {
            return
        }
        
        do {
            // Note: TerminalSession contains SSHConnection which should also be Codable
            // For now, we'll just store basic info and reconstruct
            let sessionData = try JSONDecoder().decode([PersistedSessionInfo].self, from: data)
            
            // Reconnect session info with actual connections
            recentSessions = sessionData.compactMap { info -> TerminalSession? in
                guard let connection = connections.first(where: { $0.id == info.connectionId }) else {
                    return nil
                }
                return TerminalSession(
                    id: info.id,
                    connection: connection,
                    title: info.title,
                    isActive: false
                )
            }
        } catch {
            print("Failed to load recent sessions: \(error)")
            recentSessions = []
        }
    }
    
    private func saveRecentSessions() {
        // Only persist basic info, not full sessions
        let sessionData = recentSessions.map { session -> PersistedSessionInfo in
            PersistedSessionInfo(
                id: session.id,
                connectionId: session.connection.id,
                title: session.title
            )
        }
        
        do {
            let data = try JSONEncoder().encode(sessionData)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to save recent sessions: \(error)")
        }
    }
}

// MARK: - Persisted Session Info

struct PersistedSessionInfo: Codable {
    let id: UUID
    let connectionId: UUID
    let title: String
}
