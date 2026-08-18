import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image("MoleLogo").renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.tint)
                Text("Welcome to MoleUI")
                    .font(.largeTitle.bold())
                Text("A native front end for **Mole** — the macOS maintenance CLI by tw93.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            stepCLI
            stepFullDiskAccess

            Spacer()

            Button {
                appState.onboardingComplete = true
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!vm.installed)
        }
        .padding(40)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await vm.check() }
    }

    private var stepCLI: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                statusIcon(ok: vm.installed, loading: vm.checking)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mole CLI (`mo`)").font(.headline)
                    if vm.checking {
                        Text("Checking…").foregroundStyle(.secondary)
                    } else if vm.installed {
                        Text("Installed — \(appState.moVersion.isEmpty ? "ready" : appState.moVersion)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not found. Install via Homebrew, then re-check.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Install via Homebrew") { vm.installViaHomebrew() }
                            Button("Re-check") { Task { await vm.check(); await appState.refreshInstallation() } }
                        }
                        Text("Or run manually:").font(.caption).foregroundStyle(.secondary)
                        codeBlock(OnboardingViewModel.curlCommand)
                    }
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private var stepFullDiskAccess: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lock.shield")
                    .font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Disk Access (optional)").font(.headline)
                    Text("Some cleanup tasks need Full Disk Access. Grant it to MoleUI (or Terminal, where interactive commands run) in System Settings.")
                        .foregroundStyle(.secondary)
                    Button("Open Privacy Settings") { vm.openFullDiskAccessSettings() }
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private func statusIcon(ok: Bool, loading: Bool) -> some View {
        Group {
            if loading { ProgressView().controlSize(.small) }
            else { Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red).font(.title2) }
        }
        .frame(width: 24)
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}
