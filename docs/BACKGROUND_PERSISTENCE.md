# Background Persistence in iOS

## The Problem

iOS apps **cannot maintain persistent TCP connections** (like SSH) when backgrounded. The OS suspends the app within seconds, terminating all network connections. This is an iOS limitation, not an app bug.

## The Solution: Terminal Multiplexers

**ClaudeTerm** uses **tmux** or **screen** on the **server side** to maintain sessions. The app disconnects/reconnects seamlessly.

### How It Works

1. **On Connect**: App creates or attaches to a tmux/screen session
2. **On Background**: App sends "detach" command → session keeps running on server
3. **On Foreground**: App reconnects SSH and reattaches to the same session
4. **Result**: You never lose your Claude Code session, even if iOS kills the app

### Quick Start

```bash
# Install tmux on your server (if not already)
# Ubuntu/Debian:
sudo apt-get install tmux

# macOS:
brew install tmux

# Or use screen (usually pre-installed)
```

That's it. ClaudeTerm handles the rest automatically.

### User Settings

In the app (Settings → Persistence):

- **Use tmux/screen**: Toggle automatic multiplexer integration (default: ON)
- **Auto-reconnect**: Reconnect when returning to app (default: ON)
- **Reconnection window**: How long to attempt auto-reconnect (default: 5 min)

### Manual Control

If you want to manage tmux yourself:

```bash
# Inside the terminal, these work:
tmux new-session -s mysession    # Create new
tmux attach-session -s mysession # Attach existing
tmux detach                      # Detach (keeps running)
# or press Ctrl+B then D
```

## Technical Details

### iOS Background Modes

iOS offers limited background execution:

| Mode | Can Keep Socket Alive? | Notes |
|------|------------------------|-------|
| None | No | App suspends immediately |
| `fetch` | No | Periodic wakeups only |
| `processing` | No | Limited background tasks |
| `voip` | Partial | Apple scrutinizes usage |
| `audio` | Yes (if playing) | Workaround, drains battery |

**ClaudeTerm doesn't use these hacks** — we use the proper solution (server-side persistence).

### What About "Background" SSH Apps?

Apps claiming "background SSH" either:
1. Use tmux/screen (same as us, but hidden)
2. Use VOIP/audio hacks (risk app store rejection, battery drain)
3. Misrepresent what they do

### Implementation

Key files:

- `BackgroundPersistenceManager.swift` — iOS lifecycle handling
- `MultiplexerManager.swift` — tmux/screen integration
- `TerminalViewModel.swift` — Session management

### Limitations

1. **SSH connection drops** — unavoidable on iOS
2. **Server must have tmux/screen** — we can't bundle it
3. **Reconnection takes ~1-2 seconds** — brief delay on app return

## FAQ

**Q: Can I use this without tmux/screen?**
A: Yes, but you'll lose your session when backgrounded. Fine for quick commands.

**Q: What if the server doesn't have tmux?**
A: App falls back to standard SSH. You'll get a warning about session persistence.

**Q: Does this work with mosh?**
A: Not directly — mosh requires UDP and a server-side daemon. tmux is the standard solution.

**Q: Can I run multiple Claude Code sessions?**
A: Yes — each connection gets its own tmux session name.
