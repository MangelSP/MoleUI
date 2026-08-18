import Foundation

/// Finds removable build artifacts under given roots and moves them to Trash.
/// ponytail: `find -prune` + `du` are the native tools — no walker, no watcher.
enum CleanupService {

    /// Directory names considered junk (safe, regenerable build output).
    static let patterns = ["node_modules", "target", "dist", ".build", ".next", "build", ".gradle"]

    /// Scan `roots` for junk directories, with sizes, biggest first.
    static func scan(roots: [String], patterns: [String] = patterns) async -> [JunkItem] {
        var items: [JunkItem] = []
        let fm = FileManager.default

        for root in roots where fm.fileExists(atPath: root) {
            // -prune stops descent into a match (won't recurse into node_modules).
            var args = [root, "-type", "d", "("]
            for (i, p) in patterns.enumerated() {
                if i > 0 { args.append("-o") }
                args += ["-name", p]
            }
            args += [")", "-prune", "-print"]

            guard let out = try? await ProcessRunner.run("/usr/bin/find", args) else { continue }
            let paths = out.stdout.split(separator: "\n").map(String.init)

            for path in paths {
                let size = await duBytes(path)
                let url = URL(fileURLWithPath: path)
                items.append(JunkItem(path: path, name: url.lastPathComponent,
                                      size: size, parent: url.deletingLastPathComponent().path))
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    private static func duBytes(_ path: String) async -> Int64 {
        guard let out = try? await ProcessRunner.run("/usr/bin/du", ["-sk", path]),
              let kb = Int64(out.stdout.split(separator: "\t").first ?? "") else { return 0 }
        return kb * 1024
    }

    /// Move items to Trash (reversible). Returns paths that failed.
    @discardableResult
    static func trash(_ items: [JunkItem]) -> [String] {
        var failed: [String] = []
        for item in items {
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
            } catch {
                failed.append(item.path)
            }
        }
        return failed
    }
}
