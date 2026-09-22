import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var status: DashboardViewModel
    @State private var selection: AppSection = .dashboard

    var body: some View {
        if !appState.onboardingComplete {
            OnboardingView()
        } else {
            NavigationSplitView {
                List(AppSection.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .font(.display(13, .medium))
                        .tag(section)
                }
                .navigationSplitViewColumnWidth(min: 190, ideal: 205)
                .listStyle(.sidebar)
                .safeAreaInset(edge: .bottom) { mascot }
            } detail: {
                switch selection {
                case .dashboard: DashboardView()
                case .analyze: AnalyzeView()
                case .ports: PortsView()
                case .processes: ProcessesView()
                case .network: NetworkView()
                case .maintenance: MaintenanceView()
                case .automation: AutomationView()
                case .about: AboutView()
                }
            }
            .tint(Theme.emerald)
        }
    }

    /// Sidebar mascot: mood follows the live health score / CPU / memory.
    private var mascot: some View {
        let s = status.status
        let mood: PixelCat.Mood = s.map {
            PixelCat.mood(health: $0.healthScore, cpu: $0.cpu.usage, memory: $0.memory.usedPercent)
        } ?? .box
        return VStack(spacing: 2) {
            PixelCat(mood: mood)
            Text(mood == .alarm ? "System under pressure!" : mood == .sleep ? "All quiet" : mood == .box ? "Loading…" : "Purring along")
                .font(.monoLabel(9)).foregroundStyle(mood == .alarm ? .red : .secondary)
        }
        .padding(.bottom, 10)
    }
}
