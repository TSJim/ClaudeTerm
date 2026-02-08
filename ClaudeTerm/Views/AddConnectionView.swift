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
    
    enum AuthMethod: String, CaseIterable {
        case password = "Password"
        case key = "SSH Key"
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
                    Button("Test Connection") {
                        // TODO: Test SSH connection before saving
                    }
                    .disabled(!isValid)
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
    
    private func saveConnection() {
        let connection = SSHConnection(
            name: name,
            host: host,
            port: Int(port) ?? 22,
            username: username,
            authMethod: authMethod == .password ? .password : .privateKey(keyName: selectedKey)
        )
        onSave(connection)
        dismiss()
    }
}

#Preview {
    AddConnectionView { _ in }
}
