import Foundation

// MARK: - TODOs for v0.1 MVP

/*
 
 ## Core Functionality
 - [x] Integrate NMSSH for actual SSH connections ✓
 - [x] Implement proper terminal emulation (VT100/xterm) with SwiftTerm ✓
 - [x] Add SSH key support (loads from filesystem with passphrase) ✓
 - [x] Implement proper keychain storage for passwords ✓
 - [x] Add connection testing before saving ✓
 
 ## Build System
 - [x] Create Package.swift with NMSSH and SwiftTerm dependencies ✓
 
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
 - [x] TerminalSession Hashable conformance for NavigationStack ✓
 - [x] Better terminal view with SwiftTerm incremental feeding ✓
 - [x] Support for terminal colors and formatting via SwiftTerm ✓
 - [x] Add keyboard shortcuts (arrow keys, tab, etc.) ✓
 - [ ] Font size adjustment
 - [ ] Dark/light theme support
 - [ ] Better iPhone keyboard handling (avoid occlusion)
 
 ## Claude Code Integration
 - [x] Quick action for "claude" command ✓
 - [x] Quick action for "claude --resume" ✓
 - [x] Session persistence across app restarts (tmux) ✓
 - [ ] File upload/download for Claude Code
 - [ ] Support for Claude Code's interactive features
 
 ## Security
 - [ ] Biometric auth for opening app (optional)
 - [x] SSH key passphrase stored in Keychain ✓
 - [ ] Secure enclave for SSH keys
 - [ ] Certificate validation options
 - [ ] Audit logging
 
 ## Polish
 - [ ] App icon
 - [ ] Launch screen
 - [ ] Settings panel
 - [ ] About page
 - [x] Error handling and user-friendly messages (banner + alert) ✓
 
 */

// MARK: - Known Issues (FIXED)

/*
 FIXED in latest update:
 1. ✓ Added Package.swift with NMSSH and SwiftTerm SPM dependencies
 2. ✓ TerminalSession now conforms to Hashable (for NavigationStack)
 3. ✓ SSH key auth implemented - loads keys from filesystem with passphrase support
 4. ✓ Terminal resize uses NMSSH channel.requestSizeWidth() instead of ANSI escapes
 5. ✓ SwiftTerm feeds data incrementally - only new bytes, not entire buffer
 6. ✓ Errors surfaced to UI via @Published lastError with banner + alert
 
 REMAINING:
 - Package.swift needs testing with swift build
 - SSH key auth needs testing with real keys
 - Test Connection needs timeout handling
 - Need to add import statements for NMSSH and SwiftTerm in source files
 */
