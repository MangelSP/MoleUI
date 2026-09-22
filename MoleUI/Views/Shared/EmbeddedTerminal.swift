import SwiftUI
import SwiftTerm

/// A real PTY terminal (SwiftTerm) running one command to completion.
/// `mo clean/purge/optimize` are full TUIs (arrow-key menus, sudo via osascript in GUI mode),
/// so they need a terminal emulator — no way around it with plain pipes.
struct EmbeddedTerminal: NSViewRepresentable {
    var executable: String
    var args: [String]
    var onExit: (Int32?) -> Void

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)
        tv.processDelegate = context.coordinator
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.nativeBackgroundColor = NSColor(Theme.bg)
        tv.nativeForegroundColor = .textColor
        // Inherit the user's env (PATH for brew, HOME for mo's config) and tell mo it has a real terminal.
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        tv.startProcess(executable: executable, args: args,
                        environment: env.map { "\($0)=\($1)" }, execName: nil,
                        currentDirectory: NSHomeDirectory())
        DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit) }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onExit: (Int32?) -> Void
        init(onExit: @escaping (Int32?) -> Void) { self.onExit = onExit }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { self.onExit(exitCode) }
        }
    }
}

/// Modal sheet: run `mo <args>` in an embedded terminal, report exit, dismiss.
struct TerminalSheet: View {
    var title: String
    var args: [String]
    var executable: String? = nil        // nil = mo
    var onDone: (Int32?) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var mo: String?
    @State private var exitCode: Int32?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal").foregroundStyle(Theme.emerald)
                Text(title).font(.headline)
                Text(([executable.map { ($0 as NSString).lastPathComponent } ?? "mo"] + args).joined(separator: " ")).font(.monoLabel(11)).foregroundStyle(.secondary)
                if let code = exitCode {
                    if code == 0 { PixelCat(mood: .eat, scale: 1) }
                    Label(code == 0 ? "Finished" : "Exited with \(code)",
                          systemImage: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(code == 0 ? Theme.emerald : .red).font(.callout)
                } else { ProgressView().controlSize(.small) }
                Spacer()
                Button(exitCode == nil ? "Abort" : "Done") { onDone(exitCode); dismiss() }
                    .buttonStyle(.borderedProminent).tint(exitCode == nil ? .red : Theme.emerald)
            }
            .padding(12)
            Divider()
            if let mo {
                EmbeddedTerminal(executable: mo, args: args) { exitCode = $0 }
            } else {
                PixelCat(mood: .box).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 760, height: 520)
        .background(Theme.bg)
        .task { if let executable { mo = executable } else { mo = await MoleService.shared.resolvePath() } }
    }
}
