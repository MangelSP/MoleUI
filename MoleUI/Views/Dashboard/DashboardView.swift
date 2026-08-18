import SwiftUI

struct DashboardView: View {
    // Shared with the menu-bar monitor; polling is owned at app level, not here.
    @EnvironmentObject private var vm: DashboardViewModel
    @State private var detailProcess: MoleStatus.ProcessInfo?
    @State private var detailIface: MoleStatus.NetInterface?

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 16)]

    var body: some View {
        ScrollView {
            if let s = vm.status {
                LazyVGrid(columns: columns, spacing: 16) {
                    healthCard(s)
                    cpuCard(s.cpu)
                    memoryCard(s.memory)
                    networkCard(s.network)
                    ForEach(s.disks.filter { !$0.mount.contains("CoreSimulator") }) { diskCard($0) }
                }
                .padding()

                topProcesses(s.topProcesses)
                    .padding([.horizontal, .bottom])
                    .sheet(item: $detailProcess) { ProcessDetailView(process: $0) }
                    .sheet(item: $detailIface) { NetworkDetailView(iface: $0) }
            } else if let err = vm.errorText {
                ContentUnavailableView("Couldn't load status", systemImage: "exclamationmark.triangle", description: Text(err))
                    .padding(.top, 80)
            } else {
                ProgressView("Loading system status…").padding(.top, 80)
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if vm.isLoading { ProgressView().controlSize(.small) }
            }
        }
        .task { vm.startPolling() }  // idempotent; poller lives at app level
    }

    // MARK: Cards

    private func healthCard(_ s: MoleStatus) -> some View {
        StatCard(title: "Health Score", systemImage: "heart.text.square") {
            HStack(spacing: 16) {
                RingGauge(value: Double(s.healthScore) / 100, label: "\(s.healthScore)",
                          tint: healthTint(s.healthScore))
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.healthScoreMsg).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Text("Uptime \(s.uptime) · \(s.procs) procs")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cpuCard(_ cpu: MoleStatus.CPU) -> some View {
        StatCard(title: "CPU", systemImage: "cpu") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(cpu.usage))%").font(.title2.bold().monospacedDigit())
                    Spacer()
                    Text("load \(cpu.load1, specifier: "%.1f")").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(cpu.perCore.enumerated()), id: \.offset) { i, v in
                    BarRow(label: "Core \(i)", fraction: v / 100, valueText: "\(Int(v))%")
                }
                Text("\(cpu.pCoreCount)P + \(cpu.eCoreCount)E cores")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func memoryCard(_ m: MoleStatus.Memory) -> some View {
        StatCard(title: "Memory", systemImage: "memorychip") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Bytes.string(m.used)) / \(Bytes.string(m.total))")
                    .font(.title3.bold())
                BarRow(label: "RAM", fraction: m.usedPercent / 100, valueText: "\(Int(m.usedPercent))%")
                if m.swapTotal > 0 {
                    BarRow(label: "Swap", fraction: Double(m.swapUsed) / Double(m.swapTotal),
                           valueText: Bytes.string(m.swapUsed))
                }
                Text("Cached \(Bytes.string(m.cached))").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func diskCard(_ d: MoleStatus.Disk) -> some View {
        StatCard(title: d.mount == "/" ? "Disk" : d.mount, systemImage: "internaldrive") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Bytes.string(d.used)) / \(Bytes.string(d.total))").font(.title3.bold())
                BarRow(label: d.fstype.uppercased(), fraction: d.usedPercent / 100,
                       valueText: "\(Int(d.usedPercent))%",
                       tint: d.usedPercent > 90 ? .red : .blue)
                HStack(spacing: 6) {
                    Image(systemName: d.smartStatus == "verified" ? "checkmark.seal" : "questionmark.circle")
                    Text("SMART: \(d.smartStatus)")
                }.font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func networkCard(_ ifaces: [MoleStatus.NetInterface]) -> some View {
        let active = ifaces.filter(\.isActive)
        return StatCard(title: "Network", systemImage: "network") {
            VStack(alignment: .leading, spacing: 8) {
                if active.isEmpty {
                    Text("No active interfaces").font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(active) { i in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(i.name).font(.callout.bold())
                                Text(i.ip.isEmpty ? "—" : i.ip).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("↓ \(rateString(i.rxRateMbs))").font(.caption.monospacedDigit())
                                Text("↑ \(rateString(i.txRateMbs))").font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Button { detailIface = i } label: { Image(systemName: "info.circle") }
                                .buttonStyle(.borderless).help("Interface details")
                        }
                    }
                }
            }
        }
    }

    private func topProcesses(_ procs: [MoleStatus.ProcessInfo]) -> some View {
        StatCard(title: "Top Processes", systemImage: "list.bullet.rectangle") {
            Table(procs) {
                TableColumn("Process") { Text($0.name).lineLimit(1) }
                TableColumn("CPU %") { Text("\($0.cpu, specifier: "%.1f")").monospacedDigit() }
                    .width(60)
                TableColumn("Memory") { Text(Bytes.string($0.memoryBytes)).monospacedDigit() }
                    .width(80)
                TableColumn("") { p in
                    Button { detailProcess = p } label: { Image(systemName: "info.circle") }
                        .buttonStyle(.borderless).help("Process details")
                }.width(40)
            }
            .frame(minHeight: 200)
        }
    }

    private func healthTint(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }
}

// MARK: - Reusable card chrome

struct StatCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Label(title, systemImage: systemImage).font(.headline)
        }
        .groupBoxStyle(.automatic)
    }
}

struct RingGauge: View {
    let value: Double        // 0...1
    let label: String
    var tint: Color = .accentColor

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label).font(.title2.bold().monospacedDigit())
        }
    }
}

struct BarRow: View {
    let label: String
    let fraction: Double
    let valueText: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).frame(width: 52, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 8)
            Text(valueText).font(.caption.monospacedDigit()).frame(width: 48, alignment: .trailing)
        }
    }
}
