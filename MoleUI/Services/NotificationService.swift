import Foundation
import UserNotifications

/// Posts native notifications when system metrics cross user thresholds.
/// Edge-triggered with a cooldown so a sustained problem doesn't spam.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var active: Set<String> = []          // metrics currently over threshold (edge-trigger)
    private var lastFired: [String: Date] = [:]
    private let cooldown: TimeInterval = 600       // re-alert at most every 10 min while still bad

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(_ s: MoleStatus, settings: AutomationSettings) {
        guard settings.alertsEnabled else { active.removeAll(); return }

        check("cpu", value: s.cpu.usage, threshold: settings.cpuThreshold,
              title: "CPU saturada", body: "CPU al \(Int(s.cpu.usage))%. Revisa los procesos en el Dashboard.")

        check("ram", value: s.memory.usedPercent, threshold: settings.ramThreshold,
              title: "Memoria RAM llena", body: "RAM al \(Int(s.memory.usedPercent))%. Cierra apps o usa Maintenance → Clean.")

        if let disk = s.disks.first {
            check("disk", value: disk.usedPercent, threshold: settings.diskThreshold,
                  title: "Poco espacio en disco", body: "Disco al \(Int(disk.usedPercent))%. Revisa Auto-Clean / Analyze para liberar espacio.")
        }

        // cpu_temp is 0 on Apple Silicon without elevated perms — only alert on a real reading.
        if s.thermal.cpuTemp > 0 {
            check("temp", value: s.thermal.cpuTemp, threshold: settings.tempThreshold,
                  title: "Temperatura alta", body: "CPU a \(Int(s.thermal.cpuTemp))°C.")
        }
    }

    private func check(_ key: String, value: Double, threshold: Double, title: String, body: String) {
        guard value >= threshold else { active.remove(key); return }
        let now = Date()
        let cool = lastFired[key].map { now.timeIntervalSince($0) > cooldown } ?? true
        guard !active.contains(key) || cool else { return }
        active.insert(key)
        lastFired[key] = now
        post(title, body, id: key)
    }

    func post(_ title: String, _ body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "moleui.\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
