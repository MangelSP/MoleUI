import Foundation

/// Strips ANSI escape sequences (colors, cursor moves) from CLI text so it renders
/// cleanly in a SwiftUI Text view. Mole's `--dry-run` output is heavily colored.
enum ANSISanitizer {
    // CSI sequences: ESC [ ... final-byte  (covers SGR colors, cursor ops, etc.)
    private static let regex = try! NSRegularExpression(pattern: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]")

    static func strip(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    #if DEBUG
    /// ponytail: one runnable check for the one piece of non-trivial logic here.
    static func _selfCheck() {
        let colored = "\u{1B}[1;35mClean\u{1B}[0m \u{1B}[0;33m158.0MB\u{1B}[0m"
        assert(strip(colored) == "Clean 158.0MB", "ANSISanitizer failed: \(strip(colored))")
    }
    #endif
}
