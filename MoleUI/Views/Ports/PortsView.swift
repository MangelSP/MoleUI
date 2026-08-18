import SwiftUI

struct PortsView: View {
    @StateObject private var vm = PortsViewModel()
    @State private var pendingKill: PortProcess?
    @State private var detailPort: PortProcess?
    @State private var autoRefresh = true
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .navigationTitle("Local Ports")
        .task { await vm.refresh(); startTicker() }
        .onDisappear { ticker?.cancel() }
        .sheet(item: $detailPort) { p in
            PortDetailView(port: p, allPorts: vm.ports) { target, force in
                Task { await vm.kill(target, force: force) }
            }
        }
        .confirmationDialog(
            "Stop this process?",
            isPresented: Binding(get: { pendingKill != nil }, set: { if !$0 { pendingKill = nil } }),
            presenting: pendingKill
        ) { p in
            Button("Stop \(p.command) on :\(p.port)", role: .destructive) {
                Task { await vm.kill(p) }; pendingKill = nil
            }
            Button("Force Kill (SIGKILL)", role: .destructive) {
                Task { await vm.kill(p, force: true) }; pendingKill = nil
            }
            Button("Cancel", role: .cancel) { pendingKill = nil }
        } message: { p in
            Text("Sends a terminate signal to “\(p.command)” (pid \(p.pid)) listening on port \(p.port).")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(vm.ports.count) listening")
                .foregroundStyle(.secondary)
            if let err = vm.errorText {
                Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption)
            }
            Spacer()
            Toggle("Auto", isOn: $autoRefresh)
                .toggleStyle(.switch).controlSize(.small)
                .onChange(of: autoRefresh) { _, on in on ? startTicker() : ticker?.cancel() }
            Button { Task { await vm.refresh() } } label: { Image(systemName: "arrow.clockwise") }
        }
        .padding(10)
    }

    @ViewBuilder private var content: some View {
        if vm.isLoading {
            ProgressView("Scanning ports…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.ports.isEmpty {
            ContentUnavailableView("No listening ports", systemImage: "network",
                                   description: Text("Start a local server and it will appear here."))
        } else {
            Table(vm.ports) {
                TableColumn("Port") { p in
                    HStack(spacing: 6) {
                        Text("\(p.port)").monospacedDigit().bold()
                        if p.isCommonDevPort {
                            Circle().fill(.green).frame(width: 6, height: 6)
                        }
                    }
                }.width(70)
                TableColumn("Process") { p in Text(p.command).lineLimit(1) }
                TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }.width(70)
                TableColumn("Address") { p in Text(p.address).foregroundStyle(.secondary).font(.caption) }.width(90)
                TableColumn("CPU %") { p in Text("\(p.cpu, specifier: "%.1f")").monospacedDigit() }.width(60)
                TableColumn("Memory") { p in Text(Bytes.string(p.memoryBytes)).monospacedDigit() }.width(80)
                TableColumn("") { p in
                    HStack(spacing: 10) {
                        Button { detailPort = p } label: { Image(systemName: "info.circle") }
                            .buttonStyle(.borderless).help("Details for port \(p.port)")
                        Button(role: .destructive) { pendingKill = p } label: {
                            Image(systemName: "xmark.octagon")
                        }
                        .buttonStyle(.borderless).help("Stop the process on port \(p.port)")
                    }
                }.width(80)
            }
        }
    }

    private func startTicker() {
        ticker?.cancel()
        guard autoRefresh else { return }
        ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { await vm.refresh() }
            }
        }
    }
}
