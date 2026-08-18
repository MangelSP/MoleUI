import Foundation
import AppKit

/// Interactive `mo` commands (clean/purge/optimize/uninstall) and Homebrew install
/// own their own terminal UI, so we hand them to Terminal.app rather than fighting the TUI.
enum TerminalHandoff {

    /// Open Terminal.app and run `command` in a new window.
    static func run(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}
