import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var status: MoleStatus?
    @Published var errorText: String?
    @Published var isLoading = false

    // Rolling history for sparklines (most recent last).
    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var netRxHistory: [Double] = []
    @Published var netTxHistory: [Double] = []
    private let historyCap = 40

    private func record(_ s: MoleStatus) {
        func push(_ arr: inout [Double], _ v: Double) {
            arr.append(v); if arr.count > historyCap { arr.removeFirst(arr.count - historyCap) }
        }
        push(&cpuHistory, s.cpu.usage)
        push(&memHistory, s.memory.usedPercent)
        let net = s.network.first(where: \.isActive)
        push(&netRxHistory, net?.rxRateMbs ?? 0)
        push(&netTxHistory, net?.txRateMbs ?? 0)
    }

    /// Set by the app so each poll can drive threshold notifications.
    weak var settings: AutomationSettings?

    private var pollTask: Task<Void, Never>?
    private let interval: Duration = .milliseconds(2500)

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: self?.interval ?? .seconds(3))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        if status == nil { isLoading = true }
        do {
            let fresh = try await MoleService.shared.fetchStatus()
            status = fresh
            record(fresh)
            errorText = nil
            if let settings { NotificationService.shared.evaluate(fresh, settings: settings) }
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
