import SwiftUI

struct AutomationView: View {
    @EnvironmentObject var settings: AutomationSettings
    @StateObject private var vm = CleanupViewModel()
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                alerts
                autoClean
            }
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(Theme.bg)
        .navigationTitle("Automation")
        .confirmationDialog(
            "Move \(vm.selectedItems.count) item(s) — \(Bytes.string(vm.selectedTotal)) — to Trash?",
            isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { vm.deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items go to the Trash (recoverable). Review the checked rows below before confirming.")
        }
    }

    // MARK: Alerts

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.alertsEnabled) {
                    Label("Threshold notifications", systemImage: "bell.badge").font(.display(15, .semibold))
                }
                Text("Get a macOS notification when a resource crosses its limit (edge-triggered, 10-min cooldown).")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                thresholdRow("CPU usage", value: $settings.cpuThreshold, unit: "%")
                thresholdRow("RAM usage", value: $settings.ramThreshold, unit: "%")
                thresholdRow("Disk usage", value: $settings.diskThreshold, unit: "%")
                thresholdRow("CPU temperature", value: $settings.tempThreshold, unit: "°C")
                Text("Temperature only fires when a real sensor reading is available (needs elevated perms on Apple Silicon).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .moleCard()
    }

    private func thresholdRow(_ label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label).frame(width: 150, alignment: .leading)
            Slider(value: value, in: 50...100, step: 5)
            Text("\(Int(value.wrappedValue))\(unit)").monospacedDigit().frame(width: 52, alignment: .trailing)
        }
        .disabled(!settings.alertsEnabled)
    }

    // MARK: Auto-Clean

    private var autoClean: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.autoCleanEnabled) {
                    Label("Scheduled clean job", systemImage: "clock.arrow.circlepath").font(.display(15, .semibold))
                }
                Text("Periodically scans for build junk (node_modules, target, dist, .build…) and notifies you. **Nothing is deleted automatically** — you review and confirm.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("Scan every").frame(width: 150, alignment: .leading)
                    Stepper("\(Int(settings.scanIntervalHours)) h", value: $settings.scanIntervalHours, in: 1...168, step: 1)
                        .frame(width: 120)
                    Spacer()
                }.disabled(!settings.autoCleanEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Folders to scan (one per line)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $settings.cleanRoots)
                        .font(.system(.callout, design: .monospaced))
                        .frame(height: 54)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                }

                HStack {
                    Button { Task { await vm.scan(roots: settings.roots) } } label: {
                        Label("Scan now", systemImage: "magnifyingglass")
                    }
                    if vm.isScanning { ProgressView().controlSize(.small) }
                    if let d = vm.lastScan {
                        Text("Last: \(d.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if let r = vm.resultText {
                    Label(r, systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green)
                }

                results
            }
        }
        .moleCard()
    }

    @ViewBuilder private var results: some View {
        if !vm.items.isEmpty {
            Divider()
            HStack {
                Text("\(vm.items.count) found · \(Bytes.string(vm.foundTotal)) total")
                    .font(.subheadline.bold())
                Spacer()
                Text("Selected: \(Bytes.string(vm.selectedTotal))").foregroundStyle(.secondary).font(.callout)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Move selected to Trash", systemImage: "trash")
                }
                .disabled(vm.selected.isEmpty)
            }
            ForEach(vm.items) { item in
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { vm.selected.contains(item.id) },
                        set: { on in if on { vm.selected.insert(item.id) } else { vm.selected.remove(item.id) } }
                    )).labelsHidden()
                    Image(systemName: "folder.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).bold()
                        Text(item.parent).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Text(Bytes.string(item.size)).monospacedDigit().foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
