import Foundation

/// Protocol for terminal multiplexer integration (tmux, screen)
protocol TerminalMultiplexer {
    /// Command to start a new named session
    func startSessionCommand(name: String) -> String
    
    /// Command to attach to existing session
    func attachSessionCommand(name: String) -> String
    
    /// Command to detach from current session
    func detachCommand() -> String
    
    /// Command to list available sessions
    func listSessionsCommand() -> String
    
    /// Check if currently in a multiplexer session
    func isInSession(environment: [String: String]) -> Bool
}

// MARK: - Tmux Implementation

struct TmuxMultiplexer: TerminalMultiplexer {
    func startSessionCommand(name: String) -> String {
        return "tmux new-session -A -s \(name.escapedForShell())"
    }
    
    func attachSessionCommand(name: String) -> String {
        return "tmux attach-session -t \(name.escapedForShell())"
    }
    
    func detachCommand() -> String {
        return "tmux detach"
    }
    
    func listSessionsCommand() -> String {
        return "tmux list-sessions"
    }
    
    func isInSession(environment: [String: String]) -> Bool {
        return environment["TMUX"] != nil
    }
}

// MARK: - Screen Implementation

struct ScreenMultiplexer: TerminalMultiplexer {
    func startSessionCommand(name: String) -> String {
        return "screen -S \(name.escapedForShell()) -d -R"
    }
    
    func attachSessionCommand(name: String) -> String {
        return "screen -r \(name.escapedForShell())"
    }
    
    func detachCommand() -> String {
        // Ctrl+A followed by D
        return "\u{0001}d" // \u{0001} is Ctrl+A
    }
    
    func listSessionsCommand() -> String {
        return "screen -ls"
    }
    
    func isInSession(environment: [String: String]) -> Bool {
        return environment["STY"] != nil
    }
}

// MARK: - Multiplexer Manager

class MultiplexerManager {
    let multiplexer: TerminalMultiplexer
    
    init(type: MultiplexerType = .tmux) {
        switch type {
        case .tmux:
            self.multiplexer = TmuxMultiplexer()
        case .screen:
            self.multiplexer = ScreenMultiplexer()
        }
    }
    
    enum MultiplexerType {
        case tmux
        case screen
    }
    
    /// Generate session name based on connection and timestamp
    func generateSessionName(for connection: SSHConnection) -> String {
        let sanitized = connection.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "\(sanitized)_\(Int(Date().timeIntervalSince1970))"
    }
    
    /// Full command to start Claude in a persistent session
    func startClaudeInSession(connectionName: String, resume: Bool = false) -> String {
        let sessionName = "claudeterm_\(connectionName)"
        var command = multiplexer.startSessionCommand(name: sessionName)
        command += " 'claude"
        if resume {
            command += " --resume"
        }
        command += "'"
        return command
    }
    
    /// Commands to run when app goes to background
    func prepareForBackgroundCommands() -> [String] {
        return [
            multiplexer.detachCommand()
        ]
    }
    
    /// Commands to run when app returns to foreground
    func prepareForForegroundCommands(connectionName: String) -> [String] {
        let sessionName = "claudeterm_\(connectionName)"
        return [
            multiplexer.attachSessionCommand(name: sessionName)
        ]
    }
}
