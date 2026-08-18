import Foundation

/// Rich per-process detail assembled from `ps` and `lsof` (macOS `ps` has no thcount,
/// so threads come from `ps M`). ponytail: a handful of cheap spawns, run concurrently.
struct ProcessDetail {
    var user = ""
    var started = ""
    var threads = 0
    var openFiles = 0
    var cwd = ""
    var executable = ""
    var command = ""
    var ancestry: [(name: String, pid: Int)] = []   // launchd … → this process
}

enum ProcessService {

    static func detail(pid: Int) async -> ProcessDetail {
        async let core = coreFields(pid)
        async let threads = threadCount(pid)
        async let files = openFileCount(pid)
        async let cwd = workingDir(pid)
        async let tree = ancestry(pid)

        var d = await core
        d.threads = await threads
        d.openFiles = await files
        d.cwd = await cwd
        d.ancestry = await tree
        return d
    }

    private static func ps(_ pid: Int, _ fmt: String) async -> String {
        (try? await ProcessRunner.run("/bin/ps", ["-o", fmt, "-p", String(pid)]))?
            .stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func coreFields(_ pid: Int) async -> ProcessDetail {
        var d = ProcessDetail()
        // Single-token fields together; command/comm separately (they can contain spaces).
        let meta = await ps(pid, "user=,etime=")
        let parts = meta.split(separator: " ", omittingEmptySubsequences: true)
        if parts.count >= 2 { d.user = String(parts[0]); d.started = String(parts[1]) }
        d.executable = await ps(pid, "comm=")
        d.command = await ps(pid, "command=")
        return d
    }

    private static func threadCount(_ pid: Int) async -> Int {
        guard let r = try? await ProcessRunner.run("/bin/ps", ["M", "-p", String(pid)]) else { return 0 }
        return max(0, r.stdout.split(separator: "\n").count - 1)   // minus header
    }

    private static func openFileCount(_ pid: Int) async -> Int {
        guard let r = try? await ProcessRunner.run("/usr/sbin/lsof", ["-p", String(pid)]) else { return 0 }
        return max(0, r.stdout.split(separator: "\n").count - 1)
    }

    private static func workingDir(_ pid: Int) async -> String {
        guard let r = try? await ProcessRunner.run("/usr/sbin/lsof", ["-a", "-p", String(pid), "-d", "cwd", "-Fn"])
        else { return "" }
        for line in r.stdout.split(separator: "\n") where line.hasPrefix("n") {
            return String(line.dropFirst())
        }
        return ""
    }

    private static func ancestry(_ pid: Int) async -> [(name: String, pid: Int)] {
        var chain: [(String, Int)] = []
        var current = pid
        for _ in 0..<6 {
            let line = await ps(current, "comm=,ppid=")  // "name ... ppid"
            let toks = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let ppid = toks.last.flatMap({ Int($0) }) else { break }
            let name = toks.dropLast().joined(separator: " ")
            let base = (name as NSString).lastPathComponent
            chain.insert((base.isEmpty ? "\(current)" : base, current), at: 0)
            if current == 1 || ppid == 0 { break }
            current = ppid
        }
        return chain
    }
}
