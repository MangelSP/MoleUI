import Foundation

/// Free inactive memory / disk cache with the native `purge` tool.
/// `purge` needs root, so we run it through osascript's "administrator privileges",
/// which shows macOS's own password dialog — the app never sees the password.
/// ponytail: no daemon, no helper tool; one privileged one-shot.
enum MemoryService {
    static func freeRAM() async -> Bool {
        let result = try? await ProcessRunner.run(
            "/usr/bin/osascript",
            ["-e", "do shell script \"/usr/sbin/purge\" with administrator privileges"]
        )
        return result?.exitCode == 0   // non-zero if the user cancels the auth dialog
    }
}
