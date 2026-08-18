import SwiftUI

@MainActor
final class NetworkViewModel: ObservableObject {
    @Published var processes: [NetProcess] = []
    @Published var isLoading = false
    @Published var errorText: String?

    func refresh() async {
        if processes.isEmpty { isLoading = true }
        processes = await NetworkService.topProcesses()
        isLoading = false
    }

    /// Kill a process (reuses the ports kill), then refresh.
    func kill(_ p: NetProcess, force: Bool = false) async {
        let ok = await PortsService.kill(pid: p.pid, force: force)
        if !ok && !force { errorText = "Couldn't stop \(p.name) (pid \(p.pid)). Try Force Kill." }
        else { errorText = nil }
        try? await Task.sleep(for: .milliseconds(400))
        await refresh()
    }
}
