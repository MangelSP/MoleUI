import Foundation
import AppKit

/// Builds and exports a JSON audit snapshot: full `mo status` output plus the
/// current listening ports, timestamped. ponytail: JSONSerialization composes the
/// raw status JSON with our extras — no re-modeling, no export library.
enum SnapshotService {

    /// Returns pretty-printed JSON, or nil if status can't be read.
    static func buildJSON() async -> String? {
        guard let raw = try? await MoleService.shared.rawStatusJSON(),
              let statusObj = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) else { return nil }

        let ports = await PortsService.list().map { p -> [String: Any] in
            ["port": p.port, "pid": p.pid, "command": p.command,
             "address": p.address, "cpu": p.cpu, "memoryBytes": p.memoryBytes]
        }

        let iso = ISO8601DateFormatter().string(from: Date())
        let snapshot: [String: Any] = ["generatedAt": iso, "status": statusObj, "ports": ports]

        guard let data = try? JSONSerialization.data(
            withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Prompt for a location and write the snapshot. Runs the save panel on the main actor.
    @MainActor
    static func export() async -> Bool {
        guard let json = await buildJSON() else { return false }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "moleui-snapshot-\(Int(Date().timeIntervalSince1970)).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try? json.write(to: url, atomically: true, encoding: .utf8)
        return true
    }
}
