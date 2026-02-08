import Foundation

// MARK: - TODOs for v0.1 MVP

/*
 
 ## Core Functionality
 - [ ] Integrate NMSSH or libssh2 for actual SSH connections
 - [ ] Implement proper terminal emulation (VT100/xterm)
   - Consider SwiftTerm library for terminal view
 - [ ] Add SSH key support (import from clipboard/files)
 - [ ] Implement proper keychain storage for passwords
 - [ ] Add connection testing before saving
 
 ## Background Persistence (NEW)
 - [x] Design background/foreground lifecycle handling
 - [x] Implement tmux/screen integration
 - [x] Add session state persistence
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

// MARK: - Known Issues

/*
 1. Currently using mock SSH service - no actual connections
 2. Terminal output is just a Text view - no proper terminal emulation
 3. Passwords not actually stored in Keychain yet
 4. No SSH key support
 5. Keyboard doesn't send special keys (arrows, tab, etc.)
 */
