import SwiftUI
import SwiftTerm

// MARK: - Terminal View Model for SwiftTerm
/// Observable object that bridges SSH output to SwiftTerm incrementally
class TerminalEmulatorViewModel: ObservableObject {
    private var terminalView: SwiftTerm.TerminalView?
    private let outputSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    func setTerminalView(_ view: SwiftTerm.TerminalView) {
        self.terminalView = view
    }
    
    /// Feed new data incrementally to SwiftTerm - only the new bytes, not the entire buffer
    func feed(_ data: String) {
        guard let terminalView = terminalView else { return }
        if let bytes = data.data(using: .utf8) {
            terminalView.feed(byteArray: [UInt8](bytes))
        }
    }
    
    /// Get the current terminal content as attributed string
    func getTerminalContent() -> NSAttributedString? {
        guard let terminalView = terminalView else { return nil }
        return terminalView.getAttributedString(from: terminalView.getTerminal().getScrollInvariantBuffer())
    }
    
    /// Clear the terminal
    func clear() {
        terminalView?.getTerminal().resetToInitialState()
    }
    
    /// Get current cursor position
    func getCursorPosition() -> (row: Int, col: Int)? {
        guard let terminal = terminalView?.getTerminal() else { return nil }
        return (row: terminal.getCursorRow(), col: terminal.getCursorCol())
    }
}

// MARK: - SwiftTerm Terminal View
struct TerminalEmulatorView: UIViewRepresentable {
    @StateObject private var viewModel = TerminalEmulatorViewModel()
    var onInput: (String) -> Void
    var onSizeChange: (Int, Int) -> Void
    var onViewModelReady: (TerminalEmulatorViewModel) -> Void
    
    func makeUIView(context: Context) -> SwiftTerm.TerminalView {
        let terminalView = SwiftTerm.TerminalView()
        terminalView.terminalDelegate = context.coordinator
        terminalView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminalView.backgroundColor = .black
        terminalView.nativeForegroundColor = .green
        
        // Store reference and notify parent
        viewModel.setTerminalView(terminalView)
        context.coordinator.viewModel = viewModel
        
        // Notify parent that view model is ready
        DispatchQueue.main.async {
            onViewModelReady(viewModel)
        }
        
        // Calculate initial size
        DispatchQueue.main.async {
            let size = terminalView.getTerminalSize()
            onSizeChange(size.cols, size.rows)
        }
        
        return terminalView
    }
    
    func updateUIView(_ terminalView: SwiftTerm.TerminalView, context: Context) {
        // No need to update - we feed data incrementally via viewModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput, onSizeChange: onSizeChange)
    }
    
    /// Get the view model to feed data incrementally
    func getViewModel() -> TerminalEmulatorViewModel {
        return viewModel
    }
    
    class Coordinator: TerminalViewDelegate {
        var onInput: (String) -> Void
        var onSizeChange: (Int, Int) -> Void
        weak var viewModel: TerminalEmulatorViewModel?
        
        init(onInput: @escaping (String) -> Void, onSizeChange: @escaping (Int, Int) -> Void) {
            self.onInput = onInput
            self.onSizeChange = onSizeChange
        }
        
        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            if let string = String(bytes: Array(data), encoding: .utf8) {
                onInput(string)
            }
        }
        
        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            onSizeChange(newCols, newRows)
        }
        
        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
            // Could update navigation title here via notification
            NotificationCenter.default.post(name: .terminalTitleChanged, object: title)
        }
        
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
            // Track current directory if needed
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let terminalTitleChanged = Notification.Name("terminalTitleChanged")
}

// MARK: - Main Session Terminal View (renamed to avoid collision with SwiftTerm.TerminalView)
struct SessionTerminalView: View {
    let session: TerminalSession
    @StateObject private var viewModel: TerminalViewModel
    @State private var inputText = ""
    @State private var showingSpecialKeys = false
    @State private var terminalEmulatorViewModel: TerminalEmulatorViewModel?
    
    // Error alert state
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    init(session: TerminalSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: TerminalViewModel(session: session))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Output with SwiftTerm
            TerminalEmulatorView(
                onInput: { input in
                    viewModel.sendRawInput(input)
                },
                onSizeChange: { cols, rows in
                    viewModel.resizeTerminal(columns: cols, rows: rows)
                },
                onViewModelReady: { viewModel in
                    // Capture the view model to feed data incrementally
                    terminalEmulatorViewModel = viewModel
                    self.viewModel.setTerminalFeeder(viewModel)
                }
            )
            .background(Color.black)
            
            // Error Banner
            if let error = viewModel.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.clearError()
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
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
            
            // Special Keys Bar (toggleable)
            if showingSpecialKeys {
                SpecialKeysView { key in
                    viewModel.sendRawInput(key)
                }
                .background(Color(.systemGray5))
            }
            
            // Input Area
            HStack(spacing: 8) {
                Button(action: { showingSpecialKeys.toggle() }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .rotationEffect(.degrees(showingSpecialKeys ? 180 : 0))
                }
                
                TextField("Enter command...", text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { 
                        terminalEmulatorViewModel?.clear()
                        viewModel.clearTerminal()
                    }) {
                        Label("Clear Terminal", systemImage: "eraser")
                    }
                    
                    Button(action: { viewModel.startClaudeInPersistentSession() }) {
                        Label("Start tmux Session", systemImage: "play.circle")
                    }
                    
                    Button(action: { viewModel.detachFromSession() }) {
                        Label("Detach from tmux", systemImage: "escape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert("Connection Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(viewModel.$lastError) { error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
            }
        }
    }
    
    private func sendInput() {
        guard !inputText.isEmpty else { return }
        viewModel.sendInput(inputText)
        inputText = ""
    }
}

// MARK: - Special Keys View
struct SpecialKeysView: View {
    let onKeyPress: (String) -> Void
    
    let keys: [(String, String)] = [
        ("Tab", "\t"),
        ("Ctrl+C", "\u{0003}"),
        ("Ctrl+D", "\u{0004}"),
        ("Ctrl+Z", "\u{001A}"),
        ("Ctrl+A", "\u{0001}"),
        ("Ctrl+E", "\u{0005}"),
        ("Ctrl+L", "\u{000C}"),
        ("Esc", "\u{001B}"),
        ("↑", "\u{001B}[A"),
        ("↓", "\u{001B}[B"),
        ("←", "\u{001B}[D"),
        ("→", "\u{001B}[C"),
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(keys, id: \.0) { key, code in
                    Button(key) {
                        onKeyPress(code)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Supporting Views

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
        SessionTerminalView(session: TerminalSession(
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
