import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: AppSection = .dashboard

    var body: some View {
        if !appState.onboardingComplete {
            OnboardingView()
        } else {
            NavigationSplitView {
                List(AppSection.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
                .listStyle(.sidebar)
            } detail: {
                switch selection {
                case .dashboard: DashboardView()
                case .analyze: AnalyzeView()
                case .ports: PortsView()
                case .network: NetworkView()
                case .maintenance: MaintenanceView()
                case .automation: AutomationView()
                case .about: AboutView()
                }
            }
        }
    }
}
