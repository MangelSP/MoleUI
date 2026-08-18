import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var status: MoleStatus?
    @Published var errorText: String?
    @Published var isLoading = false

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
            errorText = nil
            if let settings { NotificationService.shared.evaluate(fresh, settings: settings) }
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
