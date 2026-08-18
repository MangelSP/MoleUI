import SwiftUI
import AppKit

/// A labeled key/value row used across detail sheets.
struct DetailRow: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(mono ? .system(.callout, design: .monospaced) : .callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Detail for a single listening port: full command, related ports of the same
/// process, and stop actions.
struct PortDetailView: View {
    let port: PortProcess
    let allPorts: [PortProcess]
    var onKill: (PortProcess, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fullCommand = ""

    private var related: [PortProcess] { allPorts.filter { $0.pid == port.pid && $0.port != port.port } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Port \(port.port)", systemImage: "network").font(.title2.bold())
                if port.isCommonDevPort {
                    Text("dev").font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.green.opacity(0.2), in: Capsule()).foregroundStyle(.green)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            GroupBox {
                VStack(spacing: 8) {
                    DetailRow(label: "Process", value: port.command)
                    DetailRow(label: "PID", value: "\(port.pid)")
                    DetailRow(label: "Address", value: port.address)
                    DetailRow(label: "CPU", value: String(format: "%.1f%%", port.cpu))
                    DetailRow(label: "Memory", value: Bytes.string(port.memoryBytes))
                    DetailRow(label: "Command", value: fullCommand, mono: true)
                }.padding(6)
            }
            if !related.isEmpty {
                GroupBox("Same process, other ports") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(related) { r in
                            Text("• port \(r.port) — \(r.address)").font(.callout).monospacedDigit()
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
            }
            Spacer()
            HStack {
                Button(role: .destructive) { onKill(port, false); dismiss() } label: {
                    Label("Stop (SIGTERM)", systemImage: "xmark.octagon")
                }
                Button(role: .destructive) { onKill(port, true); dismiss() } label: {
                    Label("Force Kill", systemImage: "bolt.fill")
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 440)
        .task { fullCommand = await PortsService.fullCommand(pid: port.pid) }
    }
}

/// Format a MB/s rate compactly (KB/s when small).
func rateString(_ mbs: Double) -> String {
    if mbs < 1 { return String(format: "%.0f KB/s", mbs * 1024) }
    return String(format: "%.2f MB/s", mbs)
}

/// Detail for a network interface.
struct NetworkDetailView: View {
    let iface: MoleStatus.NetInterface
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(iface.name, systemImage: "network").font(.title2.bold())
                if iface.isActive {
                    Text("active").font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.green.opacity(0.2), in: Capsule()).foregroundStyle(.green)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            GroupBox {
                VStack(spacing: 8) {
                    DetailRow(label: "Interface", value: iface.name)
                    DetailRow(label: "IP address", value: iface.ip, mono: true)
                    DetailRow(label: "Download", value: rateString(iface.rxRateMbs))
                    DetailRow(label: "Upload", value: rateString(iface.txRateMbs))
                }.padding(6)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 420, height: 280)
    }
}

/// Detail for a process consuming the network: throughput, full command,
/// live connections (remote endpoints), and stop actions.
struct NetProcessDetailView: View {
    let proc: NetProcess
    var onKill: (NetProcess, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fullCommand = ""
    @State private var connections: [String] = []
    @State private var loadingConns = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(proc.name, systemImage: "antenna.radiowaves.left.and.right")
                    .font(.title2.bold()).lineLimit(1)
                Spacer()
                Button("Done") { dismiss() }
            }
            GroupBox {
                VStack(spacing: 8) {
                    DetailRow(label: "PID", value: "\(proc.pid)")
                    DetailRow(label: "Download", value: "\(Bytes.string(proc.rxBytesPerSec))/s")
                    DetailRow(label: "Upload", value: "\(Bytes.string(proc.txBytesPerSec))/s")
                    DetailRow(label: "Command", value: fullCommand, mono: true)
                }.padding(6)
            }
            GroupBox("Connections (\(connections.count))") {
                if loadingConns {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                } else if connections.isEmpty {
                    Text("No active TCP connections.").font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(connections.enumerated()), id: \.offset) { _, c in
                                Text(c).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.padding(6)
                    }.frame(maxHeight: 140)
                }
            }
            Spacer()
            HStack {
                Button(role: .destructive) { onKill(proc, false); dismiss() } label: {
                    Label("Stop (SIGTERM)", systemImage: "xmark.octagon")
                }
                Button(role: .destructive) { onKill(proc, true); dismiss() } label: {
                    Label("Force Kill", systemImage: "bolt.fill")
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 460)
        .task {
            fullCommand = await PortsService.fullCommand(pid: proc.pid)
            connections = await NetworkService.connections(pid: proc.pid)
            loadingConns = false
        }
    }
}

/// Read-only detail for a process from the dashboard's top-processes list.
struct ProcessDetailView: View {
    let process: MoleStatus.ProcessInfo
    @Environment(\.dismiss) private var dismiss
    @State private var fullCommand = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(process.name, systemImage: "cpu").font(.title2.bold()).lineLimit(1)
                Spacer()
                Button("Done") { dismiss() }
            }
            GroupBox {
                VStack(spacing: 8) {
                    DetailRow(label: "PID", value: "\(process.pid)")
                    DetailRow(label: "Parent PID", value: "\(process.ppid)")
                    DetailRow(label: "CPU", value: String(format: "%.1f%%", process.cpu))
                    DetailRow(label: "Memory", value: "\(Bytes.string(process.memoryBytes)) (\(String(format: "%.1f", process.memory))%)")
                    DetailRow(label: "Command", value: process.command)
                    DetailRow(label: "Full path", value: fullCommand, mono: true)
                }.padding(6)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 340)
        .task { fullCommand = await PortsService.fullCommand(pid: process.pid) }
    }
}
