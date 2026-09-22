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
