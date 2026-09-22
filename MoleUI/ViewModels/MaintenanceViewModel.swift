import SwiftUI

@MainActor
final class MaintenanceViewModel: ObservableObject {

    enum Command: String, CaseIterable, Identifiable {
        case clean, purge, optimize
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var subtitle: String {
            switch self {
            case .clean: return "Deep system cleanup + leftover app files"
            case .purge: return "Remove project build artifacts (node_modules, target, dist…)"
            case .optimize: return "Refresh caches & services"
            }
        }
        var icon: String {
            switch self {
            case .clean: return "trash"
            case .purge: return "shippingbox"
            case .optimize: return "bolt"
            }
        }
        /// Boolean flags each subcommand accepts (from `mo <cmd> --help`).
        var flags: [(flag: String, label: String)] {
            switch self {
            case .clean: return [("--debug", "Debug logs"), ("--whitelist", "Manage whitelist")]
            case .purge: return [("--yes", "No confirmation"), ("--include-empty", "Include empty dirs"),
                                 ("--paths", "Edit scan paths"), ("--debug", "Debug logs")]
            case .optimize: return [("--debug", "Debug logs"), ("--whitelist", "Manage whitelist")]
            }
        }
    }

    @Published var selected: Command = .clean { didSet { enabledFlags = [] } }
    @Published var enabledFlags: Set<String> = []
    @Published var preview = ""
    @Published var isLoading = false
    @Published var errorText: String?

    /// Non-nil while the embedded terminal is running (or finished and waiting for dismissal).
    @Published var running: (executable: String, args: [String])?
    @Published var exitCode: Int32?

    var commandLine: String { (["mo", selected.rawValue] + enabledFlags.sorted()).joined(separator: " ") }

    func loadPreview() async {
        isLoading = true
        errorText = nil
        preview = ""
        do {
            preview = try await MoleService.shared.dryRun(selected.rawValue)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    /// Run the real command in the embedded terminal.
    func run() async {
        guard let mo = await MoleService.shared.resolvePath() else {
            errorText = "mo not found"; return
        }
        exitCode = nil
        running = (mo, [selected.rawValue] + enabledFlags.sorted())
    }

    func finish() {
        running = nil
        Task { await loadPreview() }   // show the post-run state
    }

    /// Fallback: hand off to Terminal.app.
    func runInTerminal() {
        TerminalHandoff.run(commandLine)
    }
}
