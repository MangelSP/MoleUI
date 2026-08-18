import Foundation

/// Mirrors `mo analyze --json <path>`. There is no `large_files` field —
/// `entries` is the (unsorted) list of children for `path`. The UI sorts by size.
struct MoleAnalysis: Decodable {
    var path: String
    var overview: Bool
    var entries: [Entry]

    struct Entry: Decodable, Identifiable {
        var id: String { path }
        var name: String
        var path: String
        var size: Int64
        var isDir: Bool
        var cleanable: Bool?
    }

    /// Children biggest-first — the only ordering the UI ever wants.
    var sortedEntries: [Entry] { entries.sorted { $0.size > $1.size } }
}
