import SwiftUI

// MARK: - Navigation Route Enum
enum NavigationRoute: Hashable {
    case terminal(session: TerminalSession)
}

struct ContentView: View {
    @StateObject private var viewModel = ConnectionListViewModel()
    @State private var showingAddConnection = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section("Saved Connections") {
                    ForEach(viewModel.connections) { connection in
                        ConnectionRow(connection: connection)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Create session and navigate
                                let session = viewModel.createSession(for: connection)
                                navigationPath.append(NavigationRoute.terminal(session: session))
                            }
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
                        SessionRow(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                navigationPath.append(NavigationRoute.terminal(session: session))
                            }
                    }
                }
            }
            .navigationTitle("ClaudeTerm")
            .navigationDestination(for: NavigationRoute.self) { route in
                switch route {
                case .terminal(let session):
                    SessionTerminalView(session: session)
                }
            }
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
                    // Create session after adding connection and navigate
                    let session = viewModel.createSession(for: connection)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigationPath.append(NavigationRoute.terminal(session: session))
                    }
                }
            }
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
