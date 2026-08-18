import SwiftUI

/// User-configurable settings for threshold alerts and the scheduled clean job.
/// Persisted via @AppStorage so they survive relaunches.
@MainActor
final class AutomationSettings: ObservableObject {
    // Alerts
    @AppStorage("alertsEnabled") var alertsEnabled = true
    @AppStorage("cpuThreshold") var cpuThreshold = 90.0
    @AppStorage("ramThreshold") var ramThreshold = 90.0
    @AppStorage("diskThreshold") var diskThreshold = 90.0
    @AppStorage("tempThreshold") var tempThreshold = 85.0   // °C, only used when a real reading exists

    // Scheduled clean job
    @AppStorage("autoCleanEnabled") var autoCleanEnabled = false
    @AppStorage("scanIntervalHours") var scanIntervalHours = 24.0
    /// Newline-separated roots to scan. Defaults to ~/repos.
    @AppStorage("cleanRoots") var cleanRoots = "~/repos"

    var roots: [String] {
        cleanRoots.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { NSString(string: $0).expandingTildeInPath }
    }
}
