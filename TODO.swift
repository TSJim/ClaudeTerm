import Foundation

// MARK: - TODOs for v0.1 MVP

/*
 
 ## Core Functionality
 - [x] Integrate Citadel for actual SSH connections ✓
 - [x] Implement proper terminal emulation (VT100/xterm) with SwiftTerm ✓
 - [x] Add SSH key support (loads from filesystem with passphrase) ✓
 - [x] Implement proper keychain storage for passwords ✓
 - [x] Add connection testing before saving ✓
 
 ## Build System
 - [x] Create Package.swift with Citadel and SwiftTerm dependencies ✓
 - [ ] Create proper Xcode project for iOS app (SPM approach won't build iOS UI)
 
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
 - [x] Make ConnectionRow tappable with navigation ✓
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
 FIXED in latest update (5 issues from CC):
 1. ✓ Switched from NMSSH to Citadel (pure Swift, SPM-native SSH library)
 2. ✓ Renamed TerminalView to SessionTerminalView to avoid collision with SwiftTerm.TerminalView
 3. ✓ Fixed broken .onAppear closure - now uses onViewModelReady callback pattern
 4. ✓ Made ConnectionRow tappable - added NavigationLink with hidden binding for programmatic nav
 5. ✓ Updated Package.swift for Citadel (though iOS apps need Xcode project, not standalone SPM)
 
 BUILD NOTES:
 - Package.swift works for dependency resolution but iOS apps need .xcodeproj
 - Use: File → New Project in Xcode, add Citadel and SwiftTerm as SPM deps
 - Or: swift package generate-xcodeproj (if using old SwiftPM tooling)
 
 REMAINING COMPILE ISSUES TO VERIFY:
 - Need to test Citadel API imports work correctly
 - SwiftTerm import may need NIO compatibility check
 - Citadel uses async/await throughout (updated SSHService to match)
 */
