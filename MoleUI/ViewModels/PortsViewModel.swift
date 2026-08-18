import SwiftUI

@MainActor
final class PortsViewModel: ObservableObject {
    @Published var ports: [PortProcess] = []
    @Published var isLoading = false
    @Published var errorText: String?

    func refresh() async {
        if ports.isEmpty { isLoading = true }
        ports = await PortsService.list()
        isLoading = false
    }

    /// Kill a process, then refresh the list. Escalates to SIGKILL if it survives.
    func kill(_ p: PortProcess, force: Bool = false) async {
        let ok = await PortsService.kill(pid: p.pid, force: force)
        if !ok && !force {
            errorText = "Couldn't stop \(p.command) (pid \(p.pid)). Try Force Kill."
        } else {
            errorText = nil
        }
        // Give the OS a moment to release the socket before re-listing.
        try? await Task.sleep(for: .milliseconds(400))
        await refresh()
    }
}
