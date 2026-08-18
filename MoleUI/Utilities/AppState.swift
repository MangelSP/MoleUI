import SwiftUI

/// App-wide state: whether onboarding is done and whether `mo` is present.
@MainActor
final class AppState: ObservableObject {
    @AppStorage("onboardingComplete") var onboardingComplete = false
    @Published var moInstalled = false
    @Published var moVersion = ""

    func refreshInstallation() async {
        moInstalled = await MoleService.shared.checkInstallation()
        if moInstalled { moVersion = await MoleService.shared.version() }
    }
}

/// Sidebar destinations.
enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case analyze = "Analyze"
    case ports = "Ports"
    case network = "Network"
    case maintenance = "Maintenance"
    case automation = "Automation"
    case about = "About"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .analyze: return "internaldrive"
        case .ports: return "network"
        case .network: return "antenna.radiowaves.left.and.right"
        case .maintenance: return "sparkles"
        case .automation: return "bell.and.waves.left.and.right"
        case .about: return "info.circle"
        }
    }
}
