import SwiftUI

@main
struct MoleUIApp: App {
    @StateObject private var appState = AppState()
    // One shared status poller feeds both the window and the menu-bar monitor.
    @StateObject private var status = DashboardViewModel()
    @StateObject private var settings = AutomationSettings()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(appState)
                .environmentObject(status)
                .environmentObject(settings)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    #if DEBUG
                    ANSISanitizer._selfCheck()
                    #endif
                    status.settings = settings
                    NotificationService.shared.requestAuthorization()
                    status.startPolling()          // background monitoring, survives window close
                    startCleanupScheduler()
                    await appState.refreshInstallation()
                }
        }
        .windowStyle(.titleBar)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(status)
                .environmentObject(appState)
        } label: {
            // Single Label view (icon + live CPU%) — updates as the shared poller ticks.
            Label(status.status.map { "\(Int($0.cpu.usage))%" } ?? "",
                  systemImage: "gauge.with.dots.needle.67percent")
        }
        .menuBarExtraStyle(.window)
    }

    /// Background job: on the configured interval, scan for build junk and *notify* only.
    /// Never deletes — the user reviews and confirms in Automation → Auto-Clean.
    /// ponytail: a plain sleep loop; enabling/interval changes take effect next cycle.
    @MainActor private func startCleanupScheduler() {
        Task { @MainActor in
            while !Task.isCancelled {
                let hours = max(1, settings.scanIntervalHours)
                try? await Task.sleep(for: .seconds(hours * 3600))
                guard settings.autoCleanEnabled else { continue }
                let items = await CleanupService.scan(roots: settings.roots)
                let total = items.reduce(Int64(0)) { $0 + $1.size }
                if total > 0 {
                    NotificationService.shared.post(
                        "Build junk found",
                        "\(items.count) folders · \(Bytes.string(total)). Open Automation → Auto-Clean to review.",
                        id: "cleanup")
                }
            }
        }
    }
}
