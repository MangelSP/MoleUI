import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @State private var detailProcess: MoleStatus.ProcessInfo?
    @State private var detailIface: MoleStatus.NetInterface?
    @State private var freeingRAM = false

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    var body: some View {
        Group {
            if let s = vm.status {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        healthCard(s)
                        cpuCard(s)
                        gpuCard(s)
                        memoryCard(s)
                        batteryCard(s)
                        diskCard(s)
                        networkCard(s)
                        fanCard(s)
                    }
                    .padding(16)

                    processTable(s.topProcesses)
                        .padding([.horizontal, .bottom], 16)
                }
            } else if let err = vm.errorText {
                ContentUnavailableView("Couldn't load status", systemImage: "exclamationmark.triangle", description: Text(err))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large).tint(Theme.emerald)
                    Text("Reading system status…").font(.monoLabel(12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.bg)
        .navigationTitle("Dashboard")
        .task { vm.startPolling() }
        .sheet(item: $detailProcess) { ProcessDetailView(process: $0) }
        .sheet(item: $detailIface) { NetworkDetailView(iface: $0) }
    }

    // MARK: Card header

    private func header(_ title: String, _ icon: String, badge: (String, Color)? = nil) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.monoLabel(11)).tracking(1)
            }
            .foregroundStyle(Theme.emerald)
            Spacer()
            if let (t, c) = badge { Badge(t, tint: c) }
        }
    }

    // MARK: Cards

    private func healthCard(_ s: MoleStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square").font(.system(size: 11))
                    Text("HEALTH").font(.monoLabel(11)).tracking(1)
                }.foregroundStyle(Theme.emerald)
                Spacer()
                Badge(s.hardware.cpuModel.replacingOccurrences(of: "Apple ", with: ""))
                Badge(s.hardware.totalRam)
                Badge(s.hardware.osVersion)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(s.healthScore)").font(.display(40)).monospacedDigit()
                            .foregroundStyle(Theme.health(s.healthScore))
                        Text(healthWord(s.healthScore)).font(.display(16, .medium)).foregroundStyle(.secondary)
                    }
                    Text(s.healthScoreMsg).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Text("up \(s.uptime) · \(s.procs) procs").font(.monoLabel(10)).foregroundStyle(.tertiary)
                }
                Spacer()
                RingGauge(value: Double(s.healthScore) / 100, label: "\(s.healthScore)",
                          tint: Theme.health(s.healthScore))
                    .frame(width: 64, height: 64)
            }
        }
        .moleCard()
    }

    private func cpuCard(_ s: MoleStatus) -> some View {
        let cpu = s.cpu
        return VStack(alignment: .leading, spacing: 10) {
            header("CPU", "cpu",
                   badge: s.thermal.cpuTemp > 0 ? ("\(Int(s.thermal.cpuTemp))°C", Theme.amber)
                                                : ("\(cpu.pCoreCount)P+\(cpu.eCoreCount)E", .secondary))
            Readout(value: "\(Int(cpu.usage))", unit: "%", size: 30, tint: Theme.load(cpu.usage))
            CoreBars(values: cpu.perCore)
            Text("\(cpuState(cpu.usage)) · Load \(cpu.load1, specifier: "%.1f") / \(cpu.perCore.count) cores")
                .font(.monoLabel(10)).foregroundStyle(.secondary)
        }
        .moleCard()
    }

    private func memoryCard(_ s: MoleStatus) -> some View {
        let m = s.memory
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "memorychip").font(.system(size: 11))
                    Text("MEMORY").font(.monoLabel(11)).tracking(1)
                }.foregroundStyle(Theme.emerald)
                Spacer()
                Button {
                    freeingRAM = true
                    Task { let ok = await MemoryService.freeRAM(); freeingRAM = false; if ok { await vm.refresh() } }
                } label: {
                    if freeingRAM { ProgressView().controlSize(.mini) }
                    else { Label("Free RAM", systemImage: "wand.and.sparkles").font(.caption) }
                }
                .buttonStyle(.borderless).help("Purge inactive memory (asks for your password)")
                Badge(s.hardware.totalRam)
            }
            Readout(value: "\(Int(m.usedPercent))", unit: "%", size: 30, tint: Theme.load(m.usedPercent))
            Sparkline(samples: vm.memHistory, tint: Theme.load(m.usedPercent))
            Text("\(Bytes.string(m.used)) · \(Bytes.string(m.swapUsed)) swap")
                .font(.monoLabel(10)).foregroundStyle(.secondary)
        }
        .moleCard()
    }

    private func diskCard(_ s: MoleStatus) -> some View {
        let d = s.disks.first(where: { $0.mount == "/" }) ?? s.disks.first
        return VStack(alignment: .leading, spacing: 10) {
            header("DISK", "internaldrive", badge: (Bytes.string(d?.total ?? 0), .secondary))
            if let d {
                Readout(value: Bytes.string(d.total - d.used), unit: "free", size: 26)
                Meter(fraction: d.usedPercent / 100, tint: Theme.load(d.usedPercent))
                Text("\(Bytes.string(d.used)) used · \(Int(d.usedPercent))% · SMART \(d.smartStatus)")
                    .font(.monoLabel(10)).foregroundStyle(.secondary)
            }
        }
        .moleCard()
    }

    private func networkCard(_ s: MoleStatus) -> some View {
        let net = s.network.first(where: \.isActive)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "network").font(.system(size: 11))
                    Text("NETWORK").font(.monoLabel(11)).tracking(1)
                }.foregroundStyle(Theme.emerald)
                Spacer()
                if let net {
                    Button { detailIface = net } label: { Image(systemName: "info.circle") }
                        .buttonStyle(.borderless).help("Interface details")
                }
                Badge(net?.name ?? "—")
            }
            Readout(value: rateString(net?.rxRateMbs ?? 0), size: 26)
            ZStack {
                Sparkline(samples: vm.netRxHistory, tint: Theme.emerald)
                Sparkline(samples: vm.netTxHistory, tint: Theme.sky)
            }
            Text("↑ \(rateString(net?.txRateMbs ?? 0)) · \(net?.ip ?? "offline")")
                .font(.monoLabel(10)).foregroundStyle(.secondary)
        }
        .moleCard()
    }

    private func gpuCard(_ s: MoleStatus) -> some View {
        let gpu = s.gpu.first
        let usage = gpu?.usage ?? -1
        return VStack(alignment: .leading, spacing: 10) {
            header("GPU", "cpu.fill",
                   badge: s.thermal.gpuTemp > 0 ? ("\(Int(s.thermal.gpuTemp))°C", Theme.amber)
                                                : ("\(gpu?.coreCount ?? 0) cores", .secondary))
            Readout(value: usage >= 0 ? "\(Int(usage))" : "idle", unit: usage >= 0 ? "%" : nil,
                    size: 30, tint: usage >= 0 ? Theme.load(usage) : .secondary)
            Sparkline(samples: usage >= 0 ? vm.cpuHistory : [0, 0], tint: Theme.sky)
                .opacity(usage >= 0 ? 1 : 0.25)
            Text("\(usage >= 0 ? "active" : "idle") · \(gpu?.coreCount ?? 0) GPU cores")
                .font(.monoLabel(10)).foregroundStyle(.secondary)
        }
        .moleCard()
    }

    private func batteryCard(_ s: MoleStatus) -> some View {
        let t = s.thermal
        return VStack(alignment: .leading, spacing: 10) {
            header("BATTERY", "battery.100",
                   badge: s.batteries.first.map { ("\($0.capacity)% health", Color.secondary) })
            if let b = s.batteries.first {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Readout(value: "\(b.percent)", unit: "%", size: 30, tint: Theme.load(Double(100 - b.percent)))
                    Text(b.status == "charged" ? "charged" : (b.timeLeft == "0:00" ? b.status : "\(b.timeLeft) left"))
                        .font(.callout).foregroundStyle(.secondary)
                    if t.adapterPower > 0 {
                        Text("⚡\(Int(t.adapterPower))W").font(.monoLabel(11)).foregroundStyle(Theme.emerald)
                    }
                }
                Text("\(b.cycleCount) cycles · \(Int(t.batteryTemp))°C · \(b.health)")
                    .font(.monoLabel(10)).foregroundStyle(.secondary)
            } else {
                Text("No battery").font(.callout).foregroundStyle(.secondary).padding(.vertical, 8)
            }
        }
        .moleCard()
    }

    private func fanCard(_ s: MoleStatus) -> some View {
        let t = s.thermal
        return VStack(alignment: .leading, spacing: 10) {
            header("FAN", "fanblades", badge: t.systemPower > 0 ? ("\(Int(t.systemPower))W", Theme.amber) : nil)
            Readout(value: t.fanSpeed > 0 ? Int(t.fanSpeed).formatted() : "—",
                    unit: t.fanSpeed > 0 ? "RPM" : nil, size: 26)
            Text(t.fanSpeed > 0 ? "Managed by macOS · \(t.fanCount) fan\(t.fanCount == 1 ? "" : "s")"
                                : "Silent · managed by macOS")
                .font(.monoLabel(10)).foregroundStyle(.secondary)
        }
        .moleCard()
    }

    // MARK: Process table

    private func processTable(_ procs: [MoleStatus.ProcessInfo]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("TOP PROCESSES").font(.monoLabel(11)).tracking(1).foregroundStyle(Theme.emerald)
                Spacer()
                Text("CPU").font(.monoLabel(10)).foregroundStyle(.secondary).frame(width: 96, alignment: .trailing)
                Text("MEM").font(.monoLabel(10)).foregroundStyle(.secondary).frame(width: 72, alignment: .trailing)
                Spacer().frame(width: 28)
            }
            .padding(.bottom, 8)
            ForEach(procs) { p in
                Divider().overlay(Theme.hairline)
                HStack(spacing: 10) {
                    ProcIcon(pid: p.pid)
                    Text(p.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 8)
                    Capsule().fill(.white.opacity(0.06)).frame(width: 46, height: 5)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.load(p.cpu)).frame(width: 46 * min(1, p.cpu / 100), height: 5)
                        }
                    Text("\(p.cpu, specifier: "%.1f")").font(.system(.callout, design: .monospaced))
                        .foregroundStyle(p.cpu >= 50 ? Theme.amber : .primary).frame(width: 46, alignment: .trailing)
                    Text(Bytes.string(p.memoryBytes)).font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary).frame(width: 72, alignment: .trailing)
                    Button { detailProcess = p } label: { Image(systemName: "ellipsis") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary).frame(width: 28)
                }
                .padding(.vertical, 7)
            }
        }
        .moleCard()
    }

    // MARK: Helpers

    private func healthWord(_ s: Int) -> String { s >= 80 ? "Excellent" : (s >= 50 ? "Fair" : "Needs care") }
    private func cpuState(_ u: Double) -> String { u < 40 ? "normal" : (u < 75 ? "busy" : "hot") }
}

/// App icon for a pid (GUI apps), falling back to a generic glyph for daemons.
struct ProcIcon: View {
    let pid: Int
    var body: some View {
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)), let icon = app.icon {
            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
        } else {
            Image(systemName: "terminal").font(.system(size: 11)).foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
    }
}

// MARK: - Shared gauges (also used by the menu-bar monitor)

/// Signature ring — emerald gradient over a faint track with a rounded readout.
struct RingGauge: View {
    let value: Double
    let label: String
    var tint: Color = Theme.emerald
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(AngularGradient(colors: [tint.opacity(0.5), tint], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label).font(.display(20)).monospacedDigit()
        }
    }
}

struct BarRow: View {
    let label: String
    let fraction: Double
    let valueText: String
    var tint: Color = Theme.emerald
    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).frame(width: 52, alignment: .leading).lineLimit(1).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(tint).frame(width: geo.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 8)
            Text(valueText).font(.caption.monospacedDigit()).frame(width: 48, alignment: .trailing)
        }
    }
}
