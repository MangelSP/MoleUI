import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var installed = false
    @Published var checking = true

    static let brewCommand = "brew install mole"
    static let curlCommand = "curl -fsSL https://raw.githubusercontent.com/tw93/mole/main/install.sh | bash"

    func check() async {
        checking = true
        installed = await MoleService.shared.checkInstallation()
        checking = false
    }

    func installViaHomebrew() {
        TerminalHandoff.run(Self.brewCommand)
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
