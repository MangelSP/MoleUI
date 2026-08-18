import SwiftUI

/// The live monitor + quick actions shown from the menu-bar icon.
struct MenuBarView: View {
    @EnvironmentObject var status: DashboardViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let s = status.status {
                HStack(spacing: 14) {
                    RingGauge(value: Double(s.healthScore) / 100, label: "\(s.healthScore)",
                              tint: Theme.health(s.healthScore))
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Health \(s.healthScore)").font(.display(16, .semibold))
                        Text(s.healthScoreMsg).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: 6) {
                    BarRow(label: "CPU", fraction: s.cpu.usage / 100, valueText: "\(Int(s.cpu.usage))%")
                    BarRow(label: "RAM", fraction: s.memory.usedPercent / 100,
                           valueText: "\(Int(s.memory.usedPercent))%")
                    if let disk = s.disks.first {
                        BarRow(label: "Disk", fraction: disk.usedPercent / 100,
                               valueText: "\(Int(disk.usedPercent))%",
                               tint: disk.usedPercent > 90 ? .red : .accentColor)
                    }
                }
            } else {
                HStack { ProgressView().controlSize(.small); Text("Reading status…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                actionButton("Open MoleUI", "macwindow") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                actionButton("Clean in Terminal…", "trash") { TerminalHandoff.run("mo clean") }
                actionButton("Refresh", "arrow.clockwise") { Task { await status.refresh() } }
            }

            Divider()
            actionButton("Quit MoleUI", "power") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

}
