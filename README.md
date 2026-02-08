# ClaudeTerm

A purpose-built iOS terminal app for accessing Claude Code on remote servers via SSH.

> Built with SwiftUI and designed specifically for iPhone users who need reliable, persistent access to Claude Code on their own infrastructure.

## Overview

ClaudeTerm is designed specifically for iPhone users who want a streamlined, mobile-optimized experience for running Claude Code on their own remote infrastructure.

## Features (Planned)

- **SSH Connection Management** - Save and manage multiple server connections
- **Native Terminal Emulation** - Full PTY support with proper terminal emulation
- **Claude Code Optimized** - Quick actions, session persistence, mobile-friendly shortcuts
- **🔒 Background Session Persistence** - Uses tmux/screen to keep Claude Code running when app is backgrounded
- **Secure Key Management** - SSH key storage in iOS Keychain
- **iPhone-First Design** - UI optimized for smaller screens, one-handed use

## Architecture

```
ClaudeTerm/
├── Models/           # Data models (Connection, Session, etc.)
├── Views/            # SwiftUI views
├── ViewModels/       # Business logic
├── Services/         # SSH, Terminal, Keychain services
├── Utils/            # Extensions, helpers
└── Resources/        # Assets, config files
```

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **SSH Library:** NMSSH (or libssh2 via Swift wrapper)
- **Terminal Emulation:** SwiftTerm (or custom VT100 implementation)

## Getting Started

1. Open `ClaudeTerm.xcodeproj` in Xcode 15+
2. Build and run on iPhone simulator or device
3. Add your SSH connection details
4. Connect and run `claude` on your remote server

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Remote server with Claude Code installed
- SSH access to said server

## License

TBD
