import Foundation

/// A build-artifact / junk directory found by the cleanup scan.
struct JunkItem: Identifiable {
    var id: String { path }
    var path: String
    var name: String        // e.g. "node_modules"
    var size: Int64
    var parent: String      // enclosing project dir, for context
}
