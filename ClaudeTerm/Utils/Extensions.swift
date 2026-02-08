import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// Escapes a string for safe use in shell commands
    /// Uses single-quote wrapping with proper handling of inner quotes
    func escapedForShell() -> String {
        // If string contains no single quotes, wrap in single quotes (safest)
        if !self.contains("'") {
            return "'\(self)'"
        }
        
        // If string contains single quotes, we need to handle them specially
        // Single-quoted strings in shell cannot contain single quotes
        // Solution: end the single-quoted string, add an escaped quote, restart
        // 'abc' -> 'abc'\''def'
        let escaped = self.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
    
    /// Alternative: Use printf %q style escaping (more compatible but complex)
    func escapedForShellBashStyle() -> String {
        // Replace single quotes with '\''
        // This ends the single-quoted string, adds an escaped quote, then restarts
        return "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

// MARK: - Color Extensions

extension Color {
    static let terminalBlack = Color.black
    static let terminalGreen = Color.green
    static let terminalRed = Color.red
    static let terminalYellow = Color.yellow
    static let terminalBlue = Color.blue
    static let terminalMagenta = Color.purple
    static let terminalCyan = Color.cyan
    static let terminalWhite = Color.white
    static let terminalOrange = Color.orange
}
