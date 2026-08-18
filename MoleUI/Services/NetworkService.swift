import Foundation

/// Per-process network usage via `nettop`, and per-process connections via `lsof`.
/// ponytail: two nettop samples 1s apart → live rate; no packet-capture library.
enum NetworkService {

    /// Processes currently sending/receiving, by throughput (bytes/sec), biggest first.
    static func topProcesses(limit: Int = 40) async -> [NetProcess] {
        guard let out = try? await ProcessRunner.run(
            "/usr/bin/nettop",
            ["-P", "-x", "-l", "2", "-s", "1", "-J", "bytes_in,bytes_out", "-n"]
        ) else { return [] }

        // nettop prints a "bytes_in ... bytes_out" header before each of the 2 samples.
        var samples: [[String]] = []
        var current: [String] = []
        for line in out.stdout.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.contains("bytes_in") && line.contains("bytes_out") {
                if !current.isEmpty { samples.append(current) }
                current = []
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                current.append(line)
            }
        }
        if !current.isEmpty { samples.append(current) }
        guard samples.count >= 2 else { return [] }

        let s1 = parse(samples[0]), s2 = parse(samples[1])
        var result: [NetProcess] = []
        for (pid, later) in s2 {
            let earlier = s1[pid] ?? (name: later.name, inB: later.inB, outB: later.outB)
            let drx = max(0, later.inB - earlier.inB)
            let dtx = max(0, later.outB - earlier.outB)
            if drx == 0 && dtx == 0 { continue }
            result.append(NetProcess(pid: pid, name: later.name, rxBytesPerSec: drx, txBytesPerSec: dtx))
        }
        return Array(result.sorted { $0.total > $1.total }.prefix(limit))
    }

    /// Parse nettop lines of the form `<name>.<pid>   <bytes_in>   <bytes_out>`.
    /// (The name can contain spaces, e.g. "Google Chrome H.22407".)
    private static func parse(_ lines: [String]) -> [Int: (name: String, inB: Int64, outB: Int64)] {
        var map: [Int: (String, Int64, Int64)] = [:]
        for line in lines {
            let toks = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard toks.count >= 3,
                  let outB = Int64(toks[toks.count - 1]),
                  let inB = Int64(toks[toks.count - 2]) else { continue }
            let namePid = toks[0..<(toks.count - 2)].joined(separator: " ")
            guard let dot = namePid.lastIndex(of: "."),
                  let pid = Int(namePid[namePid.index(after: dot)...]) else { continue }
            let name = String(namePid[..<dot])
            map[pid] = (name, inB, outB)   // last sample of this pid wins
        }
        return map
    }

    /// Established/active TCP connections for a pid (remote endpoints), from lsof.
    static func connections(pid: Int) async -> [String] {
        guard let out = try? await ProcessRunner.run(
            "/usr/sbin/lsof", ["-nP", "-iTCP", "-a", "-p", String(pid)]
        ) else { return [] }
        var conns: [String] = []
        for line in out.stdout.split(separator: "\n").dropFirst() {   // drop header
            if let r = line.range(of: "TCP ") {
                conns.append(line[r.upperBound...].trimmingCharacters(in: .whitespaces))
            }
        }
        return conns
    }
}
