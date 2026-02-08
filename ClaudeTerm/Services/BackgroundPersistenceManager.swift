import Foundation
import UIKit
import Combine

/// Handles app lifecycle and background persistence for terminal sessions
class BackgroundPersistenceManager: ObservableObject {
    static let shared = BackgroundPersistenceManager()
    
    @Published var isInBackground = false
    @Published var lastDisconnectTime: Date?
    
    /// Time window for automatic reconnection (e.g., 5 minutes)
    let autoReconnectWindow: TimeInterval = 300 // 5 minutes
    
    /// Whether the app should attempt auto-reconnection
    var shouldAutoReconnect: Bool {
        guard let lastDisconnect = lastDisconnectTime else { return false }
        return Date().timeIntervalSince(lastDisconnect) < autoReconnectWindow
    }
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterBackground() {
        isInBackground = true
        lastDisconnectTime = Date()
        
        // Request background execution time to gracefully disconnect
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Notify all sessions to prepare for background
        NotificationCenter.default.post(
            name: .terminalWillEnterBackground,
            object: nil
        )
        
        // End background task after short delay (we don't get much time)
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    @objc private func appDidEnterForeground() {
        isInBackground = false
        
        // Notify all sessions that we're back
        NotificationCenter.default.post(
            name: .terminalDidEnterForeground,
            object: nil,
            userInfo: ["shouldAutoReconnect": shouldAutoReconnect]
        )
    }
    
    @objc private func appWillTerminate() {
        // Final cleanup - we get ~5 seconds here
        NotificationCenter.default.post(
            name: .terminalWillTerminate,
            object: nil
        )
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let terminalWillEnterBackground = Notification.Name("terminalWillEnterBackground")
    static let terminalDidEnterForeground = Notification.Name("terminalDidEnterForeground")
    static let terminalWillTerminate = Notification.Name("terminalWillTerminate")
}

// MARK: - Session State Persistence

struct PersistedSessionState: Codable {
    let sessionId: UUID
    let connectionId: UUID
    let lastCommand: String?
    let scrollbackBuffer: String
    let timestamp: Date
    let wasRunningTmux: Bool
}

class SessionStateStore {
    static let shared = SessionStateStore()
    private let userDefaults = UserDefaults.standard
    private let key = "persistedSessionStates"
    
    func saveState(_ state: PersistedSessionState) {
        var states = loadAllStates()
        states.removeAll { $0.sessionId == state.sessionId }
        states.append(state)
        
        if let encoded = try? JSONEncoder().encode(states) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    func loadState(for sessionId: UUID) -> PersistedSessionState? {
        return loadAllStates().first { $0.sessionId == sessionId }
    }
    
    func loadAllStates() -> [PersistedSessionState] {
        guard let data = userDefaults.data(forKey: key),
              let states = try? JSONDecoder().decode([PersistedSessionState].self, from: data) else {
            return []
        }
        return states
    }
    
    func clearState(for sessionId: UUID) {
        var states = loadAllStates()
        states.removeAll { $0.sessionId == sessionId }
        
        if let encoded = try? JSONEncoder().encode(states) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    func clearOldStates(olderThan interval: TimeInterval = 3600) {
        let cutoff = Date().addingTimeInterval(-interval)
        var states = loadAllStates()
        states.removeAll { $0.timestamp < cutoff }
        
        if let encoded = try? JSONEncoder().encode(states) {
            userDefaults.set(encoded, forKey: key)
        }
    }
}
