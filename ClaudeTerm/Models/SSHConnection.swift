import Foundation

// MARK: - SSH Connection Model
/// Represents a saved SSH connection configuration
/// Supports both password and private key authentication
struct SSHConnection: Identifiable, Codable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    
    enum AuthMethod: Codable {
        case password
        case privateKey(keyName: String)
    }
    
    init(id: UUID = UUID(), name: String, host: String, port: Int = 22, username: String, authMethod: AuthMethod) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
    }
}

// MARK: - Terminal Session
/// Represents an active or recent terminal session
/// Tracks connection state and last access time for session management
struct TerminalSession: Identifiable {
    let id: UUID
    let connection: SSHConnection
    var title: String
    var isActive: Bool
    var lastAccessed: Date
    
    init(id: UUID = UUID(), connection: SSHConnection, title: String, isActive: Bool = true) {
        self.id = id
        self.connection = connection
        self.title = title
        self.isActive = isActive
        self.lastAccessed = Date()
    }
}

// MARK: - Claude Command Presets
/// Quick action commands for Claude Code integration
/// These appear as buttons in the terminal view for easy access
struct ClaudeCommand: Identifiable {
    let id: UUID
    let name: String
    let command: String
    let description: String
    let icon: String
    
    static let defaults: [ClaudeCommand] = [
        ClaudeCommand(id: UUID(), name: "Start Claude", command: "claude", description: "Launch Claude Code", icon: "bubble.left.fill"),
        ClaudeCommand(id: UUID(), name: "Resume Session", command: "claude --resume", description: "Resume last session", icon: "arrow.counterclockwise"),
        ClaudeCommand(id: UUID(), name: "New Project", command: "claude --new", description: "Start fresh", icon: "plus.circle.fill"),
        ClaudeCommand(id: UUID(), name: "Settings", command: "claude config", description: "Configure Claude", icon: "gear")
    ]
}
