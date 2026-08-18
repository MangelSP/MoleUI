import Foundation

/// ponytail: stdlib ByteCountFormatter does the work — one shared instance, no custom math.
enum Bytes {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useGB, .useMB, .useKB, .useTB]
        return f
    }()

    static func string(_ value: Int64) -> String { formatter.string(fromByteCount: value) }
    static func string(_ value: Int) -> String { string(Int64(value)) }
}
