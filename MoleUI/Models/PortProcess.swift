import Foundation

/// A process listening on a local TCP port (a dev server, usually).
struct PortProcess: Identifiable {
    var id: String { "\(pid)-\(port)" }
    var port: Int
    var pid: Int
    var command: String
    var address: String       // "*", "127.0.0.1", "[::1]"
    var cpu: Double           // % (from ps)
    var memoryBytes: Int64

    /// Common local dev-server ports get a subtle highlight.
    var isCommonDevPort: Bool {
        [3000, 3001, 4200, 5000, 5173, 5432, 6379, 8000, 8080, 8888, 9000, 27017].contains(port)
    }
}
