import SwiftUI

/// `mo history --json` — one row per Mole session.
struct MoleSession: Decodable, Identifiable {
    var id: String { command + startedAt }
    var command: String
    var startedAt: String
    var endedAt: String
    var items: Int
    var size: String
    var operationCount: Int
    var failedTasks: Int
    var actions: Actions
    struct Actions: Decodable { var removed, trashed, skipped, failed, rebuilt, other: Int }

}

struct HistoryView: View {
    @State private var sessions: [MoleSession] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var logPath = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(sessions.count) sessions").foregroundStyle(.secondary)
                Spacer()
                if !logPath.isEmpty {
                    Button { NSWorkspace.shared.selectFile(logPath, inFileViewerRootedAtPath: "") } label: {
                        Label("Show log", systemImage: "doc.text")
                    }
                }
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
            }
            .padding(10)
            Divider()
            if isLoading {
                VStack(spacing: 10) { PixelCat(mood: .walk); Text("Reading history…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                ContentUnavailableView(errorText == nil ? "No history yet" : "Couldn't read history", systemImage: "clock",
                                       description: Text(errorText ?? "Run Clean, Purge, Optimize or Uninstall and it will show up here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(sessions) {
                    TableColumn("When") { s in Text(s.startedAt).monospacedDigit() }.width(150)
                    TableColumn("Command") { s in Text(s.command.capitalized).bold() }.width(90)
                    TableColumn("Freed") { s in Text(s.size).monospacedDigit().foregroundStyle(Theme.emerald) }.width(80)
                    TableColumn("Items") { s in Text("\(s.items)").monospacedDigit() }.width(60)
                    TableColumn("Removed") { s in Text("\(s.actions.removed + s.actions.trashed)").monospacedDigit() }.width(70)
                    TableColumn("Skipped") { s in Text("\(s.actions.skipped)").monospacedDigit().foregroundStyle(.secondary) }.width(70)
                    TableColumn("Failed") { s in
                        Text("\(s.actions.failed)").monospacedDigit().foregroundStyle(s.actions.failed > 0 ? .red : .secondary)
                    }.width(60)
                    TableColumn("Duration") { s in Text(duration(s)).foregroundStyle(.secondary) }.width(80)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("History")
        .task { await load() }
    }

    private func duration(_ s: MoleSession) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let a = f.date(from: s.startedAt), let b = f.date(from: s.endedAt) else { return "—" }
        let secs = Int(b.timeIntervalSince(a))
        return secs < 60 ? "\(secs)s" : "\(secs / 60)m \(secs % 60)s"
    }

    private func load() async {
        do {
            let env = try await MoleService.shared.history()
            sessions = env.sessions
            logPath = env.logs["operations"] ?? ""
            errorText = nil
        } catch { errorText = error.localizedDescription }
        isLoading = false
    }
}
