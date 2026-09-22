import SwiftUI

/// A running process, sorted by resident memory. ponytail: model + service + view in one file,
/// same pattern as PortsView; split when a second screen needs the service.
struct RunningProcess: Identifiable {
    var id: String { children == nil ? "\(pid)" : "app:\(name)" }
    var pid: Int
    var user: String
    var cpu: Double
    var memoryBytes: Int64
    var name: String
    var app: String            // "Google Chrome" for every helper under Google Chrome.app
    var path: String = ""      // full executable path from `ps comm`
    var children: [RunningProcess]? = nil   // set only on synthetic app-group rows

    /// System/critical: not ours, or shipped by macOS, or one of the few that take the session down.
    /// ponytail: heuristic; the kill button is disabled, not the context-menu (power users can still force it).
    var isSystem: Bool {
        if user != NSUserName() { return true }
        if path.hasPrefix("/System/") || path.hasPrefix("/usr/") || path.hasPrefix("/sbin/") || path.hasPrefix("/bin/") { return true }
        return ["launchd", "kernel_task", "WindowServer", "loginwindow", "Finder", "Dock", "SystemUIServer",
                "ControlCenter", "coreaudiod", "mds", "mds_stores", "launchservicesd"].contains(name)
    }

    /// The .app bundle to relaunch after a kill (nil for plain binaries/daemons).
    var appBundlePath: String? {
        guard let r = path.range(of: ".app/") else { return path.hasSuffix(".app") ? path : nil }
        return String(path[..<r.lowerBound]) + ".app"
    }

    /// Collapse processes from the same .app bundle into one expandable row.
    static func grouped(_ list: [RunningProcess]) -> [RunningProcess] {
        var byApp: [String: [RunningProcess]] = [:]
        var order: [String] = []
        for p in list {
            if byApp[p.app] == nil { order.append(p.app) }
            byApp[p.app, default: []].append(p)
        }
        return order.map { app in
            let kids = byApp[app]!
            guard kids.count > 1 else { return kids[0] }
            return RunningProcess(pid: kids[0].pid, user: kids[0].user,
                                  cpu: kids.reduce(0) { $0 + $1.cpu },
                                  memoryBytes: kids.reduce(0) { $0 + $1.memoryBytes },
                                  name: "\(app) (\(kids.count))", app: app, path: kids[0].path, children: kids)
        }
        .sorted { $0.memoryBytes > $1.memoryBytes }
    }
}

enum ProcessListService {
    /// Every process on the machine, heaviest first. `ps` is the native tool — no `mo` command for this.
    static func list() async -> [RunningProcess] {
        guard let out = try? await ProcessRunner.run(
            "/bin/ps", ["-axo", "pid=,user=,pcpu=,rss=,comm=", "-m"]
        ) else { return [] }
        return out.stdout.split(separator: "\n").compactMap { line in
            let f = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard f.count == 5, let pid = Int(f[0]) else { return nil }
            let path = String(f[4])
            let name = (path as NSString).lastPathComponent
            // First "X.app" path component names the owning app; plain binaries group by themselves.
            let app = path.components(separatedBy: "/").first { $0.hasSuffix(".app") }
                .map { String($0.dropLast(4)) } ?? name
            return RunningProcess(
                pid: pid, user: String(f[1]), cpu: Double(f[2]) ?? 0,
                memoryBytes: (Int64(f[3]) ?? 0) * 1024,                 // rss is in KB
                name: name, app: app, path: path
            )
        }
    }
}

struct ProcessesView: View {
    @EnvironmentObject private var dash: DashboardViewModel
    @State private var detail: RunningProcess?
    @State private var processes: [RunningProcess] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var search = ""
    @State private var groupByApp = true
    @AppStorage("pinnedProcesses") private var pinnedRaw = ""   // "\n"-joined app names
    @State private var pendingKill: RunningProcess?
    @State private var ticker: Task<Void, Never>?

    private var filtered: [RunningProcess] {
        let base = search.isEmpty ? processes
            : processes.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.app.localizedCaseInsensitiveContains(search) }
        let rows = groupByApp ? RunningProcess.grouped(base) : base
        // Pinned first (stable), then the memory order from ps.
        return rows.filter { isPinned($0) } + rows.filter { !isPinned($0) }
    }
    private var pinned: Set<String> { Set(pinnedRaw.split(separator: "\n").map(String.init)) }
    private func isPinned(_ p: RunningProcess) -> Bool { pinned.contains(p.app) }
    private func togglePin(_ p: RunningProcess) {
        var set = pinned
        if !set.insert(p.app).inserted { set.remove(p.app) }
        pinnedRaw = set.sorted().joined(separator: "\n")
    }
    private var totalBytes: Int64 { processes.reduce(0) { $0 + $1.memoryBytes } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationTitle("Processes")
        .searchable(text: $search, prompt: "Filter by name")
        .task { await refresh(); startTicker() }
        .onDisappear { ticker?.cancel() }
        .sheet(item: $detail) { p in
            ProcessDetailView(process: .init(pid: p.pid, ppid: 0, name: p.name, command: "",
                                             cpu: p.cpu, memory: 0, memoryBytes: p.memoryBytes))
        }
        .confirmationDialog(
            "Stop this process?",
            isPresented: Binding(get: { pendingKill != nil }, set: { if !$0 { pendingKill = nil } }),
            presenting: pendingKill
        ) { p in
            Button("Stop \(p.name)", role: .destructive) { Task { await kill(p) }; pendingKill = nil }
            Button("Force Kill (SIGKILL)", role: .destructive) { Task { await kill(p, force: true) }; pendingKill = nil }
            Button("Cancel", role: .cancel) { pendingKill = nil }
        } message: { p in
            Text(p.isSystem
                 ? "“\(p.name)” is a system process (owner \(p.user)). macOS will ask for your admin password. Killing it may log you out or destabilize the system."
                 : "Sends a terminate signal to “\(p.name)” (pid \(p.pid), \(Bytes.string(p.memoryBytes))).")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(processes.count) processes · \(Bytes.string(totalBytes)) resident")
                .foregroundStyle(.secondary)
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption)
            }
            Spacer()
            Toggle("Group by app", isOn: $groupByApp).toggleStyle(.switch).controlSize(.small)
            Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }
        }
        .padding(10)
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            VStack(spacing: 10) {
                PixelCat(mood: .walk)
                Text("Reading processes…").foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if let cpu = dash.status?.cpu {
                    CPUHistoryCard(cpu: cpu, vm: dash).padding(12)
                }
                Table(filtered, children: \.children) {
                TableColumn("Process") { p in
                    HStack(spacing: 6) {
                        if isPinned(p) {
                            Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Theme.emerald)
                        }
                        if p.isSystem {
                            Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                                .help("System process — protected")
                        }
                        Text(p.name).lineLimit(1).bold(p.children != nil)
                            .foregroundStyle(p.isSystem ? .secondary : .primary)
                    }
                }
                TableColumn("PID") { p in Text(p.children == nil ? "\(p.pid)" : "").monospacedDigit() }.width(70)
                TableColumn("User") { p in Text(p.user).foregroundStyle(.secondary).font(.caption) }.width(90)
                TableColumn("CPU %") { p in Text("\(p.cpu, specifier: "%.1f")").monospacedDigit() }.width(60)
                TableColumn("Memory") { p in Text(Bytes.string(p.memoryBytes)).monospacedDigit().bold() }.width(90)
                TableColumn("") { p in
                    HStack(spacing: 10) {
                        Button { detail = p } label: { Image(systemName: "info.circle") }
                            .buttonStyle(.borderless).help("Details for \(p.name)")
                        if p.appBundlePath != nil && !p.isSystem {
                            Button { Task { await restart(p) } } label: { Image(systemName: "arrow.counterclockwise") }
                                .buttonStyle(.borderless).help("Restart \(p.app)")
                        }
                        Button(role: .destructive) { pendingKill = p } label: { Image(systemName: "xmark.octagon") }
                            .buttonStyle(.borderless).help(p.isSystem ? "Stop \(p.name) (asks for admin password)" : "Stop \(p.name)")
                    }
                }.width(100)
                }
                .contextMenu(forSelectionType: RunningProcess.ID.self) { ids in
                    if let p = find(ids.first) {
                        Button("Details") { detail = p }
                        Button(isPinned(p) ? "Unpin" : "Pin to top") { togglePin(p) }
                        if p.appBundlePath != nil { Button("Restart \(p.app)") { Task { await restart(p) } } }
                        Divider()
                        Button("Stop (SIGTERM)", role: .destructive) { Task { await kill(p) } }
                        Button("Force Kill (SIGKILL)", role: .destructive) { Task { await kill(p, force: true) } }
                        if p.isSystem { Text("System process — asks for admin, may log you out") }
                    }
                } primaryAction: { ids in
                    if let p = find(ids.first) { detail = p }
                }
            }
        }
    }

    private func find(_ id: RunningProcess.ID?) -> RunningProcess? {
        guard let id else { return nil }
        for row in filtered {
            if row.id == id { return row }
            if let c = row.children?.first(where: { $0.id == id }) { return c }
        }
        return nil
    }

    /// Kill the app's processes, then `open` its bundle again.
    private func restart(_ p: RunningProcess) async {
        guard let bundle = p.appBundlePath else { return }
        await kill(p)
        _ = try? await ProcessRunner.run("/usr/bin/open", [bundle])
    }

    private func refresh() async {
        processes = await ProcessListService.list()
        isLoading = false
    }

    /// Own processes: plain `kill`. Other users' (root, _daemons): one `kill` under osascript's
    /// admin-privileges dialog, same trick as MemoryService — the app never sees the password.
    private func kill(_ p: RunningProcess, force: Bool = false) async {
        let targets = p.children ?? [p]
        let me = NSUserName()
        var ok = true
        for t in targets where t.user == me {
            ok = await PortsService.kill(pid: t.pid, force: force) && ok
        }
        let foreign = targets.filter { $0.user != me }.map { String($0.pid) }
        if !foreign.isEmpty {
            let cmd = "/bin/kill \(force ? "-9" : "-15") \(foreign.joined(separator: " "))"
            let r = try? await ProcessRunner.run("/usr/bin/osascript",
                ["-e", "do shell script \"\(cmd)\" with administrator privileges"])
            ok = (r?.exitCode == 0) && ok   // non-zero if the user cancels the dialog
        }
        errorText = ok ? nil : "Couldn't stop \(p.name) (pid \(p.pid)). Try Force Kill."
        try? await Task.sleep(for: .milliseconds(400))
        await refresh()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { await refresh() }
            }
        }
    }
}
