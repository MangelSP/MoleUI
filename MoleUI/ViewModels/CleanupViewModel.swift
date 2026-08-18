import SwiftUI

@MainActor
final class CleanupViewModel: ObservableObject {
    @Published var items: [JunkItem] = []
    @Published var selected: Set<String> = []
    @Published var isScanning = false
    @Published var lastScan: Date?
    @Published var resultText: String?

    func scan(roots: [String]) async {
        isScanning = true
        resultText = nil
        items = await CleanupService.scan(roots: roots)
        selected = Set(items.map(\.id))     // pre-select all found; user reviews before deleting
        lastScan = Date()
        isScanning = false
    }

    var selectedItems: [JunkItem] { items.filter { selected.contains($0.id) } }
    var selectedTotal: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var foundTotal: Int64 { items.reduce(0) { $0 + $1.size } }

    /// Delete only what the user confirmed. Moves to Trash (reversible).
    func deleteSelected() {
        let targets = selectedItems
        let failed = Set(CleanupService.trash(targets))
        let removed = targets.count - failed.count
        // Drop everything we tried to delete except the ones that failed.
        let targetIDs = Set(targets.map(\.id))
        items.removeAll { item in targetIDs.contains(item.id) && !failed.contains(item.path) }
        selected.subtract(targetIDs)
        resultText = failed.isEmpty
            ? "Moved \(removed) item(s) to Trash."
            : "Moved \(removed); \(failed.count) failed (permissions?)."
    }
}
