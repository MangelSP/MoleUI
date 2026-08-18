import SwiftUI
import AppKit

struct AnalyzeView: View {
    @StateObject private var vm = AnalyzeViewModel()
    @State private var pendingTrash: MoleAnalysis.Entry?

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            Divider()
            content
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationTitle("Disk Analyzer")
        .task { if vm.analysis == nil { await vm.analyze(nil) } }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } }),
            presenting: pendingTrash
        ) { entry in
            Button("Move “\(entry.name)” to Trash", role: .destructive) {
                _ = vm.moveToTrash(entry); pendingTrash = nil
            }
            Button("Cancel", role: .cancel) { pendingTrash = nil }
        } message: { entry in
            Text("\(entry.path)\n\(Bytes.string(entry.size)) will be moved to the Trash.")
        }
    }

    private var pathBar: some View {
        HStack(spacing: 10) {
            Button { Task { await vm.goBack() } } label: { Image(systemName: "chevron.left") }
                .disabled(!vm.canGoBack)
            Button { chooseFolder() } label: { Image(systemName: "folder") }
            Text(vm.path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1).truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { Task { await vm.analyze(nil) } } label: { Image(systemName: "arrow.clockwise") }
        }
        .padding(10)
    }

    @ViewBuilder private var content: some View {
        if vm.isLoading {
            ProgressView("Analyzing…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorText {
            ContentUnavailableView("Analysis failed", systemImage: "exclamationmark.triangle", description: Text(err))
        } else if let analysis = vm.analysis {
            List(analysis.sortedEntries) { entry in
                row(entry)
            }
            .listStyle(.inset)
        } else {
            ContentUnavailableView("Pick a folder to analyze", systemImage: "internaldrive")
        }
    }

    private func row(_ entry: MoleAnalysis.Entry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc")
                .foregroundStyle(entry.isDir ? .blue : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name).lineLimit(1)
                    if entry.cleanable == true {
                        Text("cleanable").font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                GeometryReader { geo in
                    Capsule().fill(.blue.opacity(0.35))
                        .frame(width: geo.size.width * fraction(entry.size))
                }.frame(height: 4)
            }
            Text(Bytes.string(entry.size)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture { if entry.isDir { Task { await vm.analyze(entry.path) } } }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
            }
            Button("Move to Trash…", role: .destructive) { pendingTrash = entry }
        }
    }

    private func fraction(_ size: Int64) -> Double {
        Double(size) / Double(max(vm.maxSize, 1))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: vm.path)
        if panel.runModal() == .OK, let url = panel.url {
            Task { await vm.analyze(url.path) }
        }
    }
}
