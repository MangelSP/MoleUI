import SwiftUI
import AppKit

@MainActor
final class MaintenanceViewModel: ObservableObject {

    enum Command: String, CaseIterable, Identifiable {
        case clean, purge, optimize, installer
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var subtitle: String {
            switch self {
            case .clean: return "Deep system cleanup + leftover app files"
            case .purge: return "Remove project build artifacts (node_modules, target, dist…)"
            case .optimize: return "Refresh caches & services"
            case .installer: return "Find and remove old installers (.dmg, .pkg, .iso, .xip, .zip)"
            }
        }
        var icon: String {
            switch self {
            case .clean: return "trash"
            case .purge: return "shippingbox"
            case .optimize: return "bolt"
            case .installer: return "arrow.down.doc"
            }
        }
        /// Boolean flags each subcommand accepts (from `mo <cmd> --help`).
        var flags: [(flag: String, label: String)] {
            switch self {
            case .clean: return [("--debug", "Debug logs"), ("--whitelist", "Manage whitelist")]
            case .purge: return [("--yes", "No confirmation"), ("--include-empty", "Include empty dirs"),
                                 ("--paths", "Edit scan paths"), ("--debug", "Debug logs")]
            case .optimize: return [("--debug", "Debug logs"), ("--whitelist", "Manage whitelist")]
            case .installer: return [("--debug", "Debug logs")]
            }
        }
    }

    @Published var selected: Command = .clean { didSet { enabledFlags = []; externalPath = nil } }
    @Published var enabledFlags: Set<String> = []
    /// `mo clean --external PATH`: a mounted volume to strip OS metadata from.
    @Published var externalPath: String?
    @Published var preview = ""
    @Published var isLoading = false
    @Published var errorText: String?

    /// Non-nil while the embedded terminal is running (or finished and waiting for dismissal).
    @Published var running: (executable: String, args: [String])?
    @Published var exitCode: Int32?

    var args: [String] {
        var a = [selected.rawValue] + enabledFlags.sorted()
        if selected == .clean, let externalPath { a += ["--external", externalPath] }
        return a
    }
    var commandLine: String {
        (["mo"] + args.map { $0.contains(" ") ? "\"\($0)\"" : $0 }).joined(separator: " ")
    }

    /// NSOpenPanel limited to directories, starting at /Volumes.
    func pickExternal() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        panel.prompt = "Use volume"
        panel.message = "Choose the external volume to clean"
        if panel.runModal() == .OK { externalPath = panel.url?.path }
    }

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
        running = (mo, args)
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
