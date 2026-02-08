import Foundation

// MARK: - String Extensions

extension String {
    func escapedForShell() -> String {
        // Basic shell escaping
        let specialCharacters = [" ", "'", "\"", "&", ";", "|", "<", ">", "$", "`", "\\"]
        var escaped = self
        for char in specialCharacters {
            escaped = escaped.replacingOccurrences(of: char, with: "\\\(char)")
        }
        return escaped
    }
}

// MARK: - Color Extensions

import SwiftUI

extension Color {
    static let terminalBlack = Color.black
    static let terminalGreen = Color.green
    static let terminalRed = Color.red
    static let terminalYellow = Color.yellow
    static let terminalBlue = Color.blue
    static let terminalMagenta = Color.purple
    static let terminalCyan = Color.cyan
    static let terminalWhite = Color.white
}
