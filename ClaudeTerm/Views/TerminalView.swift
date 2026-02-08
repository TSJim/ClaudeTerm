import SwiftUI

struct TerminalView: View {
    let session: TerminalSession
    @StateObject private var viewModel: TerminalViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    init(session: TerminalSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: TerminalViewModel(session: session))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.terminalOutput)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                }
                .background(Color.black)
                .foregroundColor(.green)
                .onChange(of: viewModel.terminalOutput) { _ in
                    // Auto-scroll to bottom
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Quick Actions Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ClaudeCommand.defaults) { cmd in
                        QuickActionButton(command: cmd) {
                            viewModel.sendCommand(cmd.command)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGray6))
            
            // Input Area
            HStack(spacing: 8) {
                TextField("Enter command...", text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendInput()
                    }
                
                Button(action: sendInput) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ConnectionStatusIndicator(state: viewModel.connectionState)
            }
        }
        .onAppear {
            viewModel.connect()
            isInputFocused = true
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
    
    private func sendInput() {
        guard !inputText.isEmpty else { return }
        viewModel.sendInput(inputText)
        inputText = ""
    }
}

struct QuickActionButton: View {
    let command: ClaudeCommand
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: command.icon)
                    .font(.title3)
                Text(command.name)
                    .font(.caption)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

struct ConnectionStatusIndicator: View {
    let state: ConnectionState
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }
    
    var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected, .error:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        TerminalView(session: TerminalSession(
            connection: SSHConnection(
                name: "Home Server",
                host: "192.168.1.100",
                username: "admin",
                authMethod: .password
            ),
            title: "Home Server"
        ))
    }
}
