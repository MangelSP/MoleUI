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
    }

    @Published var selected: Command = .clean
    @Published var preview = ""
    @Published var isLoading = false
    @Published var errorText: String?

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

    /// Hand the real interactive command off to Terminal.app.
    func runInTerminal() {
        TerminalHandoff.run("mo \(selected.rawValue)")
    }
}
