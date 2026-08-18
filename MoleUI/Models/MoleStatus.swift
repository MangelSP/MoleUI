import Foundation

/// Mirrors `mo status --json`. Only the fields the UI uses are modeled;
/// the decoder uses `.convertFromSnakeCase`, and unused keys are ignored.
struct MoleStatus: Decodable {
    var host: String
    var platform: String
    var uptime: String
    var procs: Int
    var healthScore: Int
    var healthScoreMsg: String
    var hardware: Hardware
    var cpu: CPU
    var memory: Memory
    var gpu: [GPU]
    var disks: [Disk]
    var thermal: Thermal
    var network: [NetInterface]
    var batteries: [Battery]
    var diskIo: DiskIO
    var topProcesses: [ProcessInfo]

    struct Thermal: Decodable {
        var cpuTemp: Double
        var gpuTemp: Double
        var batteryTemp: Double
        var fanSpeed: Double
        var fanCount: Int
        var systemPower: Double
        var adapterPower: Double
    }

    struct Battery: Decodable {
        var percent: Int
        var status: String
        var timeLeft: String
        var health: String
        var cycleCount: Int
        var capacity: Int       // % of design capacity remaining
    }

    struct DiskIO: Decodable {
        var readRate: Int64
        var writeRate: Int64
    }

    struct NetInterface: Decodable, Identifiable {
        var id: String { name }
        var name: String
        var rxRateMbs: Double
        var txRateMbs: Double
        var ip: String

        var isActive: Bool { !ip.isEmpty || rxRateMbs > 0 || txRateMbs > 0 }
    }

    struct Hardware: Decodable {
        var model: String
        var cpuModel: String
        var totalRam: String
        var diskSize: String
        var osVersion: String
    }

    struct CPU: Decodable {
        var usage: Double
        var perCore: [Double]
        var load1: Double
        var load5: Double
        var load15: Double
        var coreCount: Int
        var logicalCpu: Int
        var pCoreCount: Int
        var eCoreCount: Int
    }

    struct Memory: Decodable {
        var used: Int64
        var total: Int64
        var available: Int64
        var usedPercent: Double
        var swapUsed: Int64
        var swapTotal: Int64
        var cached: Int64
    }

    struct GPU: Decodable, Identifiable {
        var id: String { name }
        var name: String
        var usage: Double
        var coreCount: Int
    }

    struct Disk: Decodable, Identifiable {
        var id: String { mount }
        var mount: String
        var device: String
        var used: Int64
        var total: Int64
        var usedPercent: Double
        var fstype: String
        var external: Bool
        var smartStatus: String
    }

    struct ProcessInfo: Decodable, Identifiable {
        var id: Int { pid }
        var pid: Int
        var ppid: Int
        var name: String
        var command: String
        var cpu: Double
        var memory: Double
        var memoryBytes: Int64
    }
}
