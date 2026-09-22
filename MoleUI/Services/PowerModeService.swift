import Foundation

/// Thermal / fan profile through macOS's own power modes (`pmset`). Apple Silicon exposes no
/// direct fan API; Low Power = quieter, High Power (16" / Studio only) = fans allowed to spin up.
/// ponytail: one privileged pmset call via osascript's admin dialog, like MemoryService.
enum PowerModeService {
    enum Mode: String, CaseIterable { case silent = "Silent", auto = "Auto", full = "Full" }

    /// Reads `pmset -g`. `highPowerSupported` is true only when the machine reports a `powermode` key.
    static func current() async -> (mode: Mode, highPowerSupported: Bool) {
        guard let out = try? await ProcessRunner.run("/usr/bin/pmset", ["-g"]) else { return (.auto, false) }
        let lines = out.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let high = lines.contains { $0.hasPrefix("powermode") }
        if let pm = lines.first(where: { $0.hasPrefix("powermode") }), pm.hasSuffix("2") { return (.full, high) }
        if let lp = lines.first(where: { $0.hasPrefix("lowpowermode") }), lp.hasSuffix("1") { return (.silent, high) }
        return (.auto, high)
    }

    static func set(_ mode: Mode, highPowerSupported: Bool) async -> Bool {
        let cmd: String
        switch mode {
        case .silent: cmd = highPowerSupported ? "/usr/bin/pmset -a powermode 1" : "/usr/bin/pmset -a lowpowermode 1"
        case .auto:   cmd = highPowerSupported ? "/usr/bin/pmset -a powermode 0" : "/usr/bin/pmset -a lowpowermode 0"
        case .full:   cmd = "/usr/bin/pmset -a powermode 2"
        }
        let r = try? await ProcessRunner.run("/usr/bin/osascript", ["-e", "do shell script \"\(cmd)\" with administrator privileges"])
        return r?.exitCode == 0
    }
}
