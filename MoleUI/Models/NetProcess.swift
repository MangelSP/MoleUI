import Foundation

/// A process and its current network throughput (bytes/sec), from `nettop`.
struct NetProcess: Identifiable {
    var id: Int { pid }
    var pid: Int
    var name: String
    var rxBytesPerSec: Int64
    var txBytesPerSec: Int64

    var total: Int64 { rxBytesPerSec + txBytesPerSec }
}
