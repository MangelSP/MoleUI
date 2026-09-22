import SwiftUI
import AppKit

/// Tree of developer junk (tool caches, emulators, AI-tool data, per-project build output)
/// with sizes; select any nodes (multi) and move them to the Trash.
struct DevJunkView: View {
    @EnvironmentObject private var settings: AutomationSettings

    struct Node: Identifiable {
        let id: String
        let name: String
        var size: Int64
        var note = ""
        var risk: JunkLocation.Risk = .safe
        var path: String? = nil           // nil for grouping nodes
        var children: [Node]? = nil
        var leaves: [Node] { children.map { $0.flatMap(\.leaves) } ?? (path == nil ? [] : [self]) }
    }

    @State private var nodes: [Node] = []
    @State private var selection: Set<String> = []
    @State private var isLoading = true
    @State private var phase = "Measuring caches…"
    @State private var pendingTrash: [Node]?
    @State private var toolRun: (label: String, exe: String, args: [String])?
    @State private var failed: [String] = []

    private var selectedLeaves: [Node] {
        var seen = Set<String>(); var out: [Node] = []
        for n in nodes.flatMap({ [$0] + ($0.children ?? []).flatMap { [$0] + ($0.children ?? []) } }) where selection.contains(n.id) {
            for leaf in n.leaves where seen.insert(leaf.id).inserted { out.append(leaf) }
        }
        return out
    }
    private var total: Int64 { nodes.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                VStack(spacing: 10) { PixelCat(mood: .walk); Text(phase).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(nodes, children: \.children, selection: $selection) {
                    TableColumn("Name") { n in
                        HStack(spacing: 6) {
                            Image(systemName: n.children != nil ? "folder.fill" : n.path.map { $0.hasSuffix("/") ? "folder" : "doc" } ?? "folder")
                                .foregroundStyle(n.children != nil ? Theme.emerald : .secondary).font(.caption)
                            Text(n.name).bold(n.children != nil)
                            if n.risk == .review, n.path != nil {
                                Badge("review", tint: Theme.amber)
                            }
                        }
                    }
                    TableColumn("Size") { n in
                        Text(Bytes.string(n.size)).monospacedDigit().bold(n.children != nil)
                            .foregroundStyle(n.size > 1_000_000_000 ? Theme.amber : .primary)
                    }.width(90)
                    TableColumn("Note") { n in
                        Text(n.note.isEmpty ? (n.path ?? "") : n.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            .help(n.path ?? "")
                    }
                    TableColumn("") { n in
                        if n.path != nil {
                            HStack(spacing: 8) {
                                Button { reveal(n) } label: { Image(systemName: "folder") }.buttonStyle(.borderless).help("Reveal in Finder")
                                Button(role: .destructive) { pendingTrash = [n] } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                            }
                        }
                    }.width(60)
                }
                .contextMenu(forSelectionType: String.self) { _ in
                    Button("Move selected to Trash…") { pendingTrash = selectedLeaves }.disabled(selectedLeaves.isEmpty)
                }
                Divider()
                toolBar
            }
        }
        .task { await scan() }
        .confirmationDialog("Move to Trash?",
                            isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } }),
                            presenting: pendingTrash) { items in
            Button("Move \(items.count) item\(items.count == 1 ? "" : "s") (\(Bytes.string(items.reduce(0) { $0 + $1.size }))) to Trash", role: .destructive) {
                trash(items); pendingTrash = nil
            }
            Button("Cancel", role: .cancel) { pendingTrash = nil }
        } message: { items in
            let review = items.filter { $0.risk == .review }
            Text(review.isEmpty ? "Everything goes to the Trash and can be restored."
                 : "⚠︎ \(review.count) marked *review* (\(review.prefix(3).map(\.name).joined(separator: ", "))…) — slow to rebuild or holds state. Still reversible from the Trash.")
        }
        .sheet(item: Binding(get: { toolRun.map { Cmd(v: $0) } }, set: { toolRun = $0?.v })) { c in
            TerminalSheet(title: c.v.label, args: c.v.args, executable: c.v.exe) { _ in Task { await scan() } }
        }
    }
    private struct Cmd: Identifiable { let v: (label: String, exe: String, args: [String]); var id: String { v.label } }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(Bytes.string(total)) reclaimable").foregroundStyle(.secondary)
            if !failed.isEmpty { Text("\(failed.count) couldn't be trashed").font(.caption).foregroundStyle(.red) }
            Spacer()
            if !selection.isEmpty {
                Button(role: .destructive) { pendingTrash = selectedLeaves } label: {
                    Label("Trash \(selectedLeaves.count) selected · \(Bytes.string(selectedLeaves.reduce(0) { $0 + $1.size }))", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent).tint(.red)
            }
            Button { Task { await scan() } } label: { Image(systemName: "arrow.clockwise") }
        }
        .padding(10)
    }

    /// One-click external cleanups that own their data (Docker images, simulators, brew…).
    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DevJunkService.toolCommands, id: \.label) { t in
                    let installed = FileManager.default.fileExists(atPath: t.executable)
                    Button { toolRun = (t.label, t.executable, t.args) } label: {
                        Label(t.label, systemImage: "terminal").font(.caption)
                    }
                    .controlSize(.small).disabled(!installed).help(installed ? t.note : "\(t.executable) not installed")
                }
            }
            .padding(8)
        }
    }

    private func scan() async {
        isLoading = true; selection = []; failed = []
        phase = "Measuring caches…"
        let cat = await DevJunkService.scanCatalog()
        phase = "Scanning projects in \(settings.roots.map { ($0 as NSString).abbreviatingWithTildeInPath }.joined(separator: ", "))…"
        let proj = await DevJunkService.scanProjects(roots: settings.roots)

        // Caches grouped by category
        var groups: [String: [Node]] = [:]; var order: [String] = []
        for l in cat {
            if groups[l.category] == nil { order.append(l.category) }
            groups[l.category, default: []].append(Node(id: l.path, name: l.label, size: l.size, note: l.note, risk: l.risk, path: l.path))
        }
        let cacheNodes = order.map { c in
            Node(id: "cat:\(c)", name: c, size: groups[c]!.reduce(0) { $0 + $1.size }, children: groups[c]!.sorted { $0.size > $1.size })
        }.sorted { $0.size > $1.size }

        // Projects grouped by enclosing project dir
        var byProject: [String: [Node]] = [:]; var porder: [String] = []
        for j in proj {
            if byProject[j.parent] == nil { porder.append(j.parent) }
            byProject[j.parent, default: []].append(Node(id: j.path, name: j.name, size: j.size, path: j.path))
        }
        let projNodes = porder.map { p in
            Node(id: "proj:\(p)", name: (p as NSString).abbreviatingWithTildeInPath, size: byProject[p]!.reduce(0) { $0 + $1.size }, children: byProject[p]!)
        }.sorted { $0.size > $1.size }

        nodes = [
            Node(id: "root:caches", name: "Caches, emulators & AI tools", size: cacheNodes.reduce(0) { $0 + $1.size }, children: cacheNodes),
            Node(id: "root:projects", name: "Project build output (\(settings.roots.count) root\(settings.roots.count == 1 ? "" : "s"))",
                 size: projNodes.reduce(0) { $0 + $1.size },
                 note: projNodes.isEmpty ? "Nothing found — add scan folders in Automation" : "", children: projNodes),
        ]
        isLoading = false
    }

    private func trash(_ items: [Node]) {
        failed = DevJunkService.trash(items.compactMap(\.path))
        Task { await scan() }
    }

    private func reveal(_ n: Node) {
        guard let p = n.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
    }
}
