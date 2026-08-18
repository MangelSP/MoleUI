import SwiftUI

@MainActor
final class AnalyzeViewModel: ObservableObject {
    @Published var path: String
    @Published var analysis: MoleAnalysis?
    @Published var isLoading = false
    @Published var errorText: String?

    /// Breadcrumb of paths visited via drill-down, for a Back action.
    @Published private(set) var history: [String] = []

    init(path: String = NSHomeDirectory()) {
        self.path = path
    }

    func analyze(_ newPath: String? = nil, pushHistory: Bool = true) async {
        if let newPath {
            if pushHistory { history.append(path) }
            path = newPath
        }
        isLoading = true
        errorText = nil
        do {
            analysis = try await MoleService.shared.fetchAnalysis(path: path)
        } catch {
            errorText = error.localizedDescription
            analysis = nil
        }
        isLoading = false
    }

    var canGoBack: Bool { !history.isEmpty }

    func goBack() async {
        guard let previous = history.popLast() else { return }
        path = previous
        await analyze(nil)
    }

    /// Move an entry to the Trash. Returns true on success. Irreversible-ish → caller confirms first.
    func moveToTrash(_ entry: MoleAnalysis.Entry) -> Bool {
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: entry.path), resultingItemURL: nil)
            analysis?.entries.removeAll { $0.path == entry.path }
            return true
        } catch {
            errorText = "Could not move to Trash: \(error.localizedDescription)"
            return false
        }
    }

    /// Largest child size, for drawing proportional bars.
    var maxSize: Int64 { analysis?.entries.map(\.size).max() ?? 1 }
}
