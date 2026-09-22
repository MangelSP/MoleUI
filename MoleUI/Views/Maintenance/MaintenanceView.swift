import SwiftUI

struct MaintenanceView: View {
    @StateObject private var vm = MaintenanceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let run = vm.running {
                terminalHeader
                Divider()
                EmbeddedTerminal(executable: run.executable, args: run.args) { vm.exitCode = $0 }
                    .id(run.args)   // fresh terminal per run
            } else {
                picker
                Divider()
                actionBar
                preview
            }
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
            // Options for the selected command.
            HStack(spacing: 14) {
                ForEach(vm.selected.flags, id: \.flag) { f in
                    Toggle(f.label, isOn: Binding(
                        get: { vm.enabledFlags.contains(f.flag) },
                        set: { on in if on { vm.enabledFlags.insert(f.flag) } else { vm.enabledFlags.remove(f.flag) } }
                    ))
                    .toggleStyle(.checkbox).controlSize(.small)
                }
                if vm.selected == .clean {
                    Button { vm.pickExternal() } label: {
                        Label(vm.externalPath.map { ($0 as NSString).lastPathComponent } ?? "External volume…",
                              systemImage: "externaldrive")
                    }
                    .controlSize(.small)
                    if vm.externalPath != nil {
                        Button { vm.externalPath = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary).help("Clear external volume")
                    }
                }
                Spacer()
                Text(vm.commandLine).font(.monoLabel(11)).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
            Text("Below is a **dry-run preview** — nothing is deleted until you run.")
                .font(.callout)
            if let err = vm.errorText {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            Spacer()
            Button { vm.runInTerminal() } label: { Label("Terminal.app", systemImage: "terminal") }
            Button { Task { await vm.run() } } label: { Label("Run \(vm.selected.title)", systemImage: "play.fill") }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.yellow.opacity(0.12))
    }

    private var terminalHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal").foregroundStyle(Theme.emerald)
            Text(vm.commandLine).font(.monoLabel(12))
            if let code = vm.exitCode {
                Label(code == 0 ? "Finished" : "Exited with \(code)",
                      systemImage: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(code == 0 ? Theme.emerald : .red).font(.callout)
            } else {
                ProgressView().controlSize(.small)
                Text("Running — interact below").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(vm.exitCode == nil ? "Abort" : "Done") { vm.finish() }
                .buttonStyle(.borderedProminent)
                .tint(vm.exitCode == nil ? .red : Theme.emerald)
        }
        .padding(12)
    }

    @ViewBuilder private var preview: some View {
        if vm.isLoading {
            ProgressView("Generating preview…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.preview.isEmpty, vm.errorText != nil {
            ContentUnavailableView("Preview failed", systemImage: "exclamationmark.triangle", description: Text(vm.errorText ?? ""))
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
