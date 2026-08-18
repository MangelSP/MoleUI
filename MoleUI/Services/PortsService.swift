import Foundation

/// Lists processes listening on local TCP ports and can terminate them.
/// ponytail: `lsof` + `ps` are the native tools for this — no library, no `mo` command exists.
enum PortsService {

    /// All listening TCP ports for the current user, enriched with CPU/memory, sorted by port.
    static func list() async -> [PortProcess] {
        guard let out = try? await ProcessRunner.run(
            "/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"]
        ) else { return [] }

        var rows: [(pid: Int, command: String, address: String, port: Int)] = []
        var seen = Set<String>()
        var pid = 0
        var command = ""

        for raw in out.stdout.split(separator: "\n") {
            guard let tag = raw.first else { continue }
            let value = raw.dropFirst()
            switch tag {
            case "p": pid = Int(value) ?? 0
            case "c": command = String(value)
            case "n":
                // value: "*:3000", "127.0.0.1:8080", "[::1]:27017"
                guard let colon = value.lastIndex(of: ":"),
                      let port = Int(value[value.index(after: colon)...]) else { break }
                let key = "\(pid)-\(port)"
                if seen.insert(key).inserted {
                    rows.append((pid, command, String(value[..<colon]), port))
                }
            default: break
            }
        }

        let stats = await psStats(pids: Set(rows.map(\.pid)))
        return rows.map { r in
            let s = stats[r.pid]
            return PortProcess(port: r.port, pid: r.pid, command: r.command,
                               address: r.address, cpu: s?.cpu ?? 0, memoryBytes: s?.rss ?? 0)
        }
        .sorted { $0.port < $1.port }
    }

    /// Batch `ps` lookup: pid -> (cpu%, rss bytes).
    private static func psStats(pids: Set<Int>) async -> [Int: (cpu: Double, rss: Int64)] {
        guard !pids.isEmpty,
              let out = try? await ProcessRunner.run(
                "/bin/ps", ["-o", "pid=,pcpu=,rss=", "-p", pids.map(String.init).joined(separator: ",")]
              ) else { return [:] }

        var result: [Int: (Double, Int64)] = [:]
        for line in out.stdout.split(separator: "\n") {
            let f = line.split(separator: " ", omittingEmptySubsequences: true)
            guard f.count >= 3, let pid = Int(f[0]) else { continue }
            result[pid] = (Double(f[1]) ?? 0, (Int64(f[2]) ?? 0) * 1024)  // rss is in KB
        }
        return result
    }

    /// Full command line for a pid (`ps -o command=`), for detail views.
    static func fullCommand(pid: Int) async -> String {
        guard let out = try? await ProcessRunner.run("/bin/ps", ["-o", "command=", "-p", String(pid)])
        else { return "" }
        return out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Send SIGTERM (or SIGKILL when `force`) to a pid. Returns true on exit code 0.
    @discardableResult
    static func kill(pid: Int, force: Bool = false) async -> Bool {
        let signal = force ? "-9" : "-15"
        let result = try? await ProcessRunner.run("/bin/kill", [signal, String(pid)])
        return result?.exitCode == 0
    }
}
