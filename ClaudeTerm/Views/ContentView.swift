import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ConnectionListViewModel()
    @State private var showingAddConnection = false
    @State private var selectedConnection: SSHConnection? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section("Saved Connections") {
                    ForEach(viewModel.connections) { connection in
                        ConnectionRow(connection: connection)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Create session and trigger navigation
                                let session = viewModel.createSession(for: connection)
                                selectedConnection = connection
                            }
                            .background(
                                NavigationLink(
                                    destination: destinationView(for: connection),
                                    tag: connection.id,
                                    selection: Binding(
                                        get: { selectedConnection?.id },
                                        set: { newValue in
                                            if newValue == nil {
                                                selectedConnection = nil
                                            }
                                        }
                                    )
                                ) {
                                    EmptyView()
                                }
                                .hidden()
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteConnection(connection)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                
                Section("Recent Sessions") {
                    ForEach(viewModel.recentSessions) { session in
                        NavigationLink(destination: SessionTerminalView(session: session)) {
                            SessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("ClaudeTerm")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddConnection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddConnection) {
                AddConnectionView { connection in
                    viewModel.addConnection(connection)
                    // Create session after adding connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedConnection = connection
                    }
                }
            }
        }
    }
    
    private func destinationView(for connection: SSHConnection) -> some View {
        // Find or create session for this connection
        if let existingSession = viewModel.recentSessions.first(where: { 
            $0.connection.id == connection.id && $0.isActive 
        }) {
            return AnyView(SessionTerminalView(session: existingSession))
        } else {
            let newSession = viewModel.createSession(for: connection)
            return AnyView(SessionTerminalView(session: newSession))
        }
    }
}

struct ConnectionRow: View {
    let connection: SSHConnection
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name)
                    .font(.headline)
                Text("\(connection.username)@\(connection.host):\(connection.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SessionRow: View {
    let session: TerminalSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                Text(session.connection.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(session.isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
