import SwiftUI

struct MaintenanceView: View {
    @StateObject private var vm = MaintenanceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            picker
            Divider()
            handoffBanner
            preview
        }
        .background(Theme.bg)
        .navigationTitle("Maintenance")
        .task(id: vm.selected) { await vm.loadPreview() }
    }

    private var picker: some View {
        VStack(spacing: 10) {
            Picker("", selection: $vm.selected) {
                ForEach(MaintenanceViewModel.Command.allCases) { cmd in
                    Label(cmd.title, systemImage: cmd.icon).tag(cmd)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(vm.selected.subtitle)
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private var handoffBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
            Text("Below is a **dry-run preview** — nothing is deleted. `mo \(vm.selected.rawValue)` is interactive, so it runs in Terminal.")
                .font(.callout)
            Spacer()
            Button {
                vm.runInTerminal()
            } label: {
                Label("Run in Terminal", systemImage: "terminal")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.yellow.opacity(0.12))
    }

    @ViewBuilder private var preview: some View {
        if vm.isLoading {
            ProgressView("Generating preview…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorText {
            ContentUnavailableView("Preview failed", systemImage: "exclamationmark.triangle", description: Text(err))
        } else {
            ScrollView {
                Text(vm.preview.isEmpty ? "No preview output." : vm.preview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
