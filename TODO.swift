import Foundation

// MARK: - TODOs for v0.1 MVP

/*
 
 ## Core Functionality
 - [x] Integrate NMSSH for actual SSH connections ✓
 - [x] Implement proper terminal emulation (VT100/xterm) with SwiftTerm ✓
 - [x] Add SSH key support (import from clipboard/files)
 - [x] Implement proper keychain storage for passwords ✓
 - [x] Add connection testing before saving ✓
 
 ## Connection Persistence
 - [x] Design background/foreground lifecycle handling ✓
 - [x] Implement tmux/screen integration ✓
 - [x] Add session state persistence ✓
 - [x] Implement UserDefaults persistence for connections ✓
 - [ ] Test multiplexer command integration with real SSH
 - [ ] Add user preference for multiplexer type (tmux vs screen)
 - [ ] Implement tmux availability detection on server
 - [ ] Add UI indicator showing multiplexer status
 
 ## UI/UX
 - [ ] Better terminal view with proper scrolling
 - [ ] Support for terminal colors and formatting
 - [ ] Add keyboard shortcuts (arrow keys, tab, etc.)
 - [ ] Font size adjustment
 - [ ] Dark/light theme support
 - [ ] Better iPhone keyboard handling (avoid occlusion)
 
 ## Claude Code Integration
 - [ ] Quick action for "claude" command
 - [ ] Quick action for "claude --resume"
 - [ ] Session persistence across app restarts
 - [ ] File upload/download for Claude Code
 - [ ] Support for Claude Code's interactive features
 
 ## Security
 - [ ] Biometric auth for opening app (optional)
 - [ ] Secure enclave for SSH keys
 - [ ] Certificate validation options
 - [ ] Audit logging
 
 ## Polish
 - [ ] App icon
 - [ ] Launch screen
 - [ ] Settings panel
 - [ ] About page
 - [ ] Error handling and user-friendly messages
 
 */

// MARK: - Known Issues (FIXED)

/*
 FIXED in this update:
 1. ✓ SSH now uses real NMSSH library with PTY support
 2. ✓ Terminal uses SwiftTerm for proper VT100 emulation
 3. ✓ Passwords stored/retrieved from iOS Keychain
 4. ✓ Connection persistence via UserDefaults
 5. ✓ Special keys supported (arrows, tab, Ctrl+C, etc.)
 
 REMAINING:
 - SSH key auth still needs implementation
 - Scrollback limit needs stress testing
 - Test Connection needs timeout handling
 */
