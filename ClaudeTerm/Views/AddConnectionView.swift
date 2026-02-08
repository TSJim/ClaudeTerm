import SwiftUI

struct AddConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SSHConnection) -> Void
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: AuthMethod = .password
    @State private var password = ""
    @State private var selectedKey = ""
    
    @State private var isTesting = false
    @State private var testResult: TestResult?
    
    enum AuthMethod: String, CaseIterable {
        case password = "Password"
        case key = "SSH Key"
    }
    
    enum TestResult {
        case success
        case failure(String)
        
        var message: String {
            switch self {
            case .success:
                return "✓ Connection successful!"
            case .failure(let msg):
                return "✗ \(msg)"
            }
        }
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .failure:
                return .red
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !host.isEmpty && !username.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Connection Details") {
                    TextField("Name (e.g., Home Server)", text: $name)
                    TextField("Host (IP or domain)", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Authentication") {
                    Picker("Method", selection: $authMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    switch authMethod {
                    case .password:
                        SecureField("Password", text: $password)
                    case .key:
                        // TODO: List available SSH keys
                        Text("SSH key selection coming soon")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(!isValid || isTesting)
                    
                    if let result = testResult {
                        Text(result.message)
                            .foregroundColor(result.color)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConnection()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func testConnection() {
        guard isValid else { return }
        
        isTesting = true
        testResult = nil
        
        let connection = createConnection()
        
        Task {
            let sshService = SSHService()
            
            do {
                var testPassword: String? = nil
                if case .password = connection.authMethod {
                    testPassword = password
                }
                
                try await sshService.connect(to: connection, password: testPassword)
                
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
                
                // Disconnect after successful test
                sshService.disconnect()
                
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }
    
    private func saveConnection() {
        let connection = createConnection()
        
        // Save password to Keychain if using password auth
        if case .password = connection.authMethod, !password.isEmpty {
            do {
                try KeychainService.shared.savePassword(
                    password,
                    for: connection.username,
                    server: "\(connection.host):\(connection.port)"
                )
            } catch {
                print("Failed to save password to Keychain: \(error)")
            }
        }
        
        onSave(connection)
        dismiss()
    }
    
    private func createConnection() -> SSHConnection {
        return SSHConnection(
            name: name,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            authMethod: authMethod == .password ? .password : .privateKey(keyName: selectedKey)
        )
    }
}

#Preview {
    AddConnectionView { _ in }
}
