import SwiftUI
import AppKit

/// Installed .app bundles → `mo uninstall <name>` in the embedded terminal.
/// ponytail: FileManager listing + du, no Spotlight query.
struct InstalledApp: Identifiable {
    var id: String { path }
    var name: String
    var path: String
    var sizeBytes: Int64
    var icon: NSImage
}

struct AppsView: View {
    @State private var apps: [InstalledApp] = []
    @State private var isLoading = true
    @State private var search = ""
    @State private var selection: Set<String> = []
    @State private var pending: [String]?      // app names to uninstall
    @State private var dryRun = false

    private var filtered: [InstalledApp] {
        search.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
    private var selectedNames: [String] { apps.filter { selection.contains($0.id) }.map(\.name) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(apps.count) apps · \(Bytes.string(apps.reduce(0) { $0 + $1.sizeBytes }))").foregroundStyle(.secondary)
                Spacer()
                Toggle("Dry run", isOn: $dryRun).toggleStyle(.switch).controlSize(.small)
                Button { pending = selectedNames } label: {
                    Label("Uninstall \(selection.count) selected", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent).tint(.red).disabled(selection.isEmpty)
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
            }
            .padding(10)
            Divider()
            if isLoading {
                VStack(spacing: 10) { PixelCat(mood: .walk); Text("Scanning applications…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filtered, selection: $selection) {
                    TableColumn("App") { a in
                        HStack(spacing: 8) {
                            Image(nsImage: a.icon).resizable().frame(width: 20, height: 20)
                            Text(a.name)
                        }
                    }
                    TableColumn("Size") { a in Text(Bytes.string(a.sizeBytes)).monospacedDigit() }.width(90)
                    TableColumn("Location") { a in Text(a.path).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    TableColumn("") { a in
                        Button(role: .destructive) { pending = [a.name] } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).help("Uninstall \(a.name) and its leftovers")
                    }.width(36)
                }
                .contextMenu(forSelectionType: String.self) { ids in
                    let names = apps.filter { ids.contains($0.id) }.map(\.name)
                    Button("Uninstall \(names.count == 1 ? names[0] : "\(names.count) apps")…") { pending = names }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(ids.map { URL(fileURLWithPath: $0) })
                    }
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("Apps")
        .searchable(text: $search, prompt: "Filter apps")
        .task { await load() }
        .sheet(item: Binding(get: { pending.map { Names(list: $0) } }, set: { pending = $0?.list })) { p in
            TerminalSheet(title: "Uninstall", args: ["uninstall"] + (dryRun ? ["--dry-run"] : []) + p.list) { _ in
                Task { await load() }
            }
        }
    }

    private struct Names: Identifiable { let list: [String]; var id: String { list.joined() } }

    private func load() async {
        let roots = ["/Applications", NSHomeDirectory() + "/Applications"]
        var found: [InstalledApp] = []
        for root in roots {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for n in names where n.hasSuffix(".app") {
                let path = root + "/" + n
                found.append(InstalledApp(name: String(n.dropLast(4)), path: path,
                                          sizeBytes: await du(path),
                                          icon: NSWorkspace.shared.icon(forFile: path)))
            }
        }
        apps = found.sorted { $0.sizeBytes > $1.sizeBytes }
        isLoading = false
    }

    private func du(_ path: String) async -> Int64 {
        guard let out = try? await ProcessRunner.run("/usr/bin/du", ["-sk", path]),
              let kb = Int64(out.stdout.split(separator: "\t").first ?? "") else { return 0 }
        return kb * 1024
    }
}
