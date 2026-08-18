import Foundation

/// Typed wrappers over the `mo` CLI. All heavy lifting delegates to ProcessRunner.
actor MoleService {
    static let shared = MoleService()

    private var cachedPath: String?

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static let candidatePaths = ["/opt/homebrew/bin/mo", "/usr/local/bin/mo"]

    /// Resolve the `mo` binary once. Checks known Homebrew locations, then `which`.
    func resolvePath() async -> String? {
        if let cachedPath { return cachedPath }
        let fm = FileManager.default
        for p in Self.candidatePaths where fm.isExecutableFile(atPath: p) {
            cachedPath = p; return p
        }
        // Fall back to `which mo` through a login-ish PATH.
        if let result = try? await ProcessRunner.run("/usr/bin/which", ["mo"]),
           result.exitCode == 0 {
            let p = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p.isEmpty { cachedPath = p; return p }
        }
        return nil
    }

    func checkInstallation() async -> Bool {
        await resolvePath() != nil
    }

    private func mo(_ args: [String]) async throws -> ProcessRunner.Result {
        guard let path = await resolvePath() else { throw MoleError.notInstalled }
        return try await ProcessRunner.run(path, args)
    }

    private func decode<T: Decodable>(_ type: T.Type, from result: ProcessRunner.Result) throws -> T {
        guard result.exitCode == 0 else {
            throw MoleError.exitCode(result.exitCode, stderr: result.stderr)
        }
        do {
            return try Self.decoder.decode(T.self, from: Data(result.stdout.utf8))
        } catch {
            throw MoleError.decode(underlying: error)
        }
    }

    func fetchStatus() async throws -> MoleStatus {
        try decode(MoleStatus.self, from: try await mo(["status", "--json"]))
    }

    func fetchAnalysis(path: String) async throws -> MoleAnalysis {
        try decode(MoleAnalysis.self, from: try await mo(["analyze", "--json", path]))
    }

    /// `mo <command> --dry-run`, with ANSI colors stripped for display.
    func dryRun(_ command: String) async throws -> String {
        let result = try await mo([command, "--dry-run"])
        // Dry-run prints to stdout; exit code is 0 even with a preview.
        let text = result.stdout.isEmpty ? result.stderr : result.stdout
        return ANSISanitizer.strip(text)
    }

    func version() async -> String {
        guard let r = try? await mo(["--version"]) else { return "unknown" }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Where `mo` lives: the resolved binary path (symlinks followed).
    func installLocation() async -> String? {
        guard let p = await resolvePath() else { return nil }
        return URL(fileURLWithPath: p).resolvingSymlinksInPath().path
    }

    /// Full status JSON as a raw string (for snapshot export).
    func rawStatusJSON() async throws -> String {
        try await mo(["status", "--json"]).stdout
    }
}
