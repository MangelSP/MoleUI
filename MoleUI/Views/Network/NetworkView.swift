import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var status: DashboardViewModel   // for interfaces
    @StateObject private var vm = NetworkViewModel()
    @State private var detail: NetProcess?
    @State private var pendingKill: NetProcess?
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            interfaces
            Divider()
            header
            content
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationTitle("Network")
        .task { await vm.refresh(); startTicker() }
        .onDisappear { ticker?.cancel() }
        .sheet(item: $detail) { p in
            NetProcessDetailView(proc: p) { target, force in Task { await vm.kill(target, force: force) } }
        }
        .confirmationDialog(
            "Stop this process?",
            isPresented: Binding(get: { pendingKill != nil }, set: { if !$0 { pendingKill = nil } }),
            presenting: pendingKill
        ) { p in
            Button("Stop \(p.name)", role: .destructive) { Task { await vm.kill(p) }; pendingKill = nil }
            Button("Force Kill", role: .destructive) { Task { await vm.kill(p, force: true) }; pendingKill = nil }
            Button("Cancel", role: .cancel) { pendingKill = nil }
        } message: { p in
            Text("Sends a terminate signal to “\(p.name)” (pid \(p.pid)).")
        }
    }

    private var interfaces: some View {
        let active = (status.status?.network ?? []).filter(\.isActive)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(active) { i in
                    HStack(spacing: 10) {
                        Image(systemName: "wifi").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(i.name).font(.callout.bold())
                            Text(i.ip).font(.caption2).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("↓ \(rateString(i.rxRateMbs))").font(.caption.monospacedDigit())
                            Text("↑ \(rateString(i.txRateMbs))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }.padding(10)
        }
    }

    private var header: some View {
        HStack {
            Text("Apps using the network").font(.headline)
            if vm.isLoading { ProgressView().controlSize(.small) }
            if let e = vm.errorText { Text(e).font(.caption).foregroundStyle(.red) }
            Spacer()
            Text("live rate").font(.caption).foregroundStyle(.secondary)
            Button { Task { await vm.refresh() } } label: { Image(systemName: "arrow.clockwise") }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    @ViewBuilder private var content: some View {
        if vm.processes.isEmpty && !vm.isLoading {
            ContentUnavailableView("No network activity", systemImage: "antenna.radiowaves.left.and.right",
                                   description: Text("No process is sending or receiving right now."))
        } else {
            Table(vm.processes) {
                TableColumn("Process") { p in Text(p.name).lineLimit(1) }
                TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }.width(70)
                TableColumn("↓ Download") { p in Text("\(Bytes.string(p.rxBytesPerSec))/s").monospacedDigit() }.width(110)
                TableColumn("↑ Upload") { p in Text("\(Bytes.string(p.txBytesPerSec))/s").monospacedDigit() }.width(110)
                TableColumn("") { p in
                    HStack(spacing: 10) {
                        Button { detail = p } label: { Image(systemName: "info.circle") }
                            .buttonStyle(.borderless).help("Details & connections")
                        Button(role: .destructive) { pendingKill = p } label: { Image(systemName: "xmark.octagon") }
                            .buttonStyle(.borderless).help("Kill \(p.name)")
                    }
                }.width(80)
            }
        }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { await vm.refresh() }
            }
        }
    }
}
