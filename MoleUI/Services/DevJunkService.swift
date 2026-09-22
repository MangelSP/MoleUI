import Foundation

/// Developer junk: global tool caches, emulator images, AI-tool data, and per-project build
/// output. Everything goes to the Trash (reversible). ponytail: a static catalog + `du`;
/// no plugin system, add a line to `catalog` when a new tool shows up.
struct JunkLocation: Identifiable, Hashable {
    enum Risk { case safe, review }   // review = rebuilding is slow or it holds user state
    var id: String { path }
    let category: String
    let label: String
    let path: String                  // absolute, ~ expanded
    let risk: Risk
    let note: String
    var size: Int64 = 0
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

enum DevJunkService {
    static let home = NSHomeDirectory()
    private static func h(_ p: String) -> String { home + "/" + p }

    static let catalog: [JunkLocation] = [
        // Flutter / Dart
        .init(category: "Flutter / Dart", label: "pub cache", path: h(".pub-cache"), risk: .safe, note: "Packages re-download on next `pub get`"),
        .init(category: "Flutter / Dart", label: "Dart analysis server cache", path: h(".dartServer"), risk: .safe, note: "Rebuilt automatically"),
        .init(category: "Flutter / Dart", label: "Flutter DevTools", path: h(".flutter-devtools"), risk: .safe, note: ""),
        // Android / Java
        .init(category: "Android / Java", label: "Gradle caches", path: h(".gradle/caches"), risk: .safe, note: "Dependencies re-download on next build"),
        .init(category: "Android / Java", label: "Gradle daemons", path: h(".gradle/daemon"), risk: .safe, note: "Daemon logs"),
        .init(category: "Android / Java", label: "Maven repository", path: h(".m2/repository"), risk: .safe, note: "Re-downloads on next build"),
        .init(category: "Android / Java", label: "Android emulators (AVD)", path: h(".android/avd"), risk: .review, note: "Deletes every virtual device — recreate in Android Studio"),
        .init(category: "Android / Java", label: "Android system images", path: h("Library/Android/sdk/system-images"), risk: .review, note: "Emulator OS images — re-download in SDK Manager"),
        .init(category: "Android / Java", label: "Android cache", path: h(".android/cache"), risk: .safe, note: ""),
        // Xcode / iOS
        .init(category: "Xcode / iOS", label: "DerivedData", path: h("Library/Developer/Xcode/DerivedData"), risk: .safe, note: "All Xcode build output; next build is a full build"),
        .init(category: "Xcode / iOS", label: "Xcode Archives", path: h("Library/Developer/Xcode/Archives"), risk: .review, note: "Signed .xcarchive builds you may still need for App Store symbols"),
        .init(category: "Xcode / iOS", label: "iOS device support", path: h("Library/Developer/Xcode/iOS DeviceSupport"), risk: .safe, note: "Re-copied when a device connects"),
        .init(category: "Xcode / iOS", label: "Simulator caches", path: h("Library/Developer/CoreSimulator/Caches"), risk: .safe, note: ""),
        .init(category: "Xcode / iOS", label: "CocoaPods cache", path: h("Library/Caches/CocoaPods"), risk: .safe, note: ""),
        // JavaScript
        .init(category: "JavaScript", label: "npm cache", path: h(".npm/_cacache"), risk: .safe, note: ""),
        .init(category: "JavaScript", label: "Yarn cache", path: h("Library/Caches/Yarn"), risk: .safe, note: ""),
        .init(category: "JavaScript", label: "pnpm store", path: h("Library/pnpm/store"), risk: .safe, note: ""),
        .init(category: "JavaScript", label: "Playwright browsers", path: h("Library/Caches/ms-playwright"), risk: .safe, note: "Re-download with `npx playwright install`"),
        .init(category: "JavaScript", label: "Puppeteer browsers", path: h(".cache/puppeteer"), risk: .safe, note: ""),
        .init(category: "JavaScript", label: "node-gyp headers", path: h("Library/Caches/node-gyp"), risk: .safe, note: ""),
        // .NET
        .init(category: ".NET", label: "NuGet packages", path: h(".nuget/packages"), risk: .safe, note: "Re-restore on next build"),
        .init(category: ".NET", label: "dotnet tool cache", path: h(".dotnet/toolResolverCache"), risk: .safe, note: ""),
        .init(category: ".NET", label: "template engine cache", path: h(".templateengine"), risk: .safe, note: ""),
        // Python
        .init(category: "Python", label: "pip cache", path: h("Library/Caches/pip"), risk: .safe, note: ""),
        .init(category: "Python", label: "pip cache (XDG)", path: h(".cache/pip"), risk: .safe, note: ""),
        .init(category: "Python", label: "uv cache", path: h(".cache/uv"), risk: .safe, note: ""),
        // Docker / system
        .init(category: "Docker / System", label: "Docker CLI data", path: h(".docker"), risk: .review, note: "Contexts + buildx state (not images — use Prune below)"),
        .init(category: "Docker / System", label: "Homebrew downloads", path: h("Library/Caches/Homebrew"), risk: .safe, note: "`brew cleanup` equivalent"),
        .init(category: "Docker / System", label: "Go build cache", path: h("Library/Caches/go-build"), risk: .safe, note: ""),
        .init(category: "Docker / System", label: "Cargo registry", path: h(".cargo/registry"), risk: .safe, note: ""),
        // AI tools — never the whole dir: those hold settings and auth.
        .init(category: "AI tools", label: "Claude Code — session transcripts", path: h(".claude/projects"), risk: .review, note: "Conversation history for --resume; settings are NOT here"),
        .init(category: "AI tools", label: "Claude Code — file history", path: h(".claude/file-history"), risk: .safe, note: "Undo snapshots"),
        .init(category: "AI tools", label: "Claude Code — shell snapshots", path: h(".claude/shell-snapshots"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Claude Code — debug logs", path: h(".claude/debug"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Claude Code — telemetry", path: h(".claude/telemetry"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Claude Desktop — VM bundles", path: h("Library/Application Support/Claude/vm_bundles"), risk: .review, note: "Cloud/local agent VM images — re-download when used"),
        .init(category: "AI tools", label: "Claude Desktop — simulator builds", path: h("Library/Application Support/Claude/simulator-builds"), risk: .safe, note: "iOS simulator app builds"),
        .init(category: "AI tools", label: "Claude Desktop — web cache", path: h("Library/Application Support/Claude/Partitions"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Claude Desktop — Cache", path: h("Library/Application Support/Claude/Cache"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Claude Desktop — Code Cache", path: h("Library/Application Support/Claude/Code Cache"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Claude Desktop — Caches", path: h("Library/Caches/com.anthropic.claudefordesktop"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Codex — sessions & logs", path: h(".codex/sessions"), risk: .review, note: ""),
        .init(category: "AI tools", label: "Cursor — extensions", path: h(".cursor/extensions"), risk: .review, note: "Reinstalled from the marketplace"),
        .init(category: "AI tools", label: "Cursor — project index", path: h(".cursor/projects"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Cursor — cache", path: h("Library/Application Support/Cursor/Cache"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Cursor — CachedData", path: h("Library/Application Support/Cursor/CachedData"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Antigravity — extensions", path: h(".antigravity/extensions"), risk: .review, note: "Reinstalled from the marketplace"),
        .init(category: "AI tools", label: "Antigravity — cache", path: h("Library/Application Support/Antigravity/Cache"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Antigravity — CachedData", path: h("Library/Application Support/Antigravity/CachedData"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Antigravity — Crashpad", path: h("Library/Application Support/Antigravity/Crashpad"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Gemini — Antigravity IDE data", path: h(".gemini/antigravity-ide"), risk: .review, note: ""),
        .init(category: "AI tools", label: "Gemini — Antigravity CLI data", path: h(".gemini/antigravity-cli"), risk: .review, note: ""),
        .init(category: "AI tools", label: "Gemini — browser profile", path: h(".gemini/antigravity-browser-profile"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Gemini — tmp", path: h(".gemini/tmp"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "Orca — cache", path: h("Library/Application Support/Orca/Cache"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "VS Code — Cache", path: h("Library/Application Support/Code/Cache"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "VS Code — CachedData", path: h("Library/Application Support/Code/CachedData"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "VS Code — extension VSIX cache", path: h("Library/Application Support/Code/CachedExtensionVSIXs"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "VS Code — web partitions", path: h("Library/Application Support/Code/Partitions"), risk: .safe, note: ""),
        .init(category: "AI tools", label: "JetBrains caches", path: h("Library/Caches/JetBrains"), risk: .safe, note: ""),
    ]

    /// Per-project junk: directory names and file globs. Superset of CleanupService.patterns.
    static let projectDirs = ["node_modules", ".next", ".nuxt", ".turbo", ".parcel-cache", "dist", "build", "out", ".output",
                              "target", ".gradle", ".dart_tool", "Pods", "bin", "obj", "__pycache__", ".pytest_cache",
                              ".mypy_cache", ".ruff_cache", ".tox", ".venv", "venv", "coverage", ".angular", ".cache", "DerivedData"]
    static let projectFiles = ["*.apk", "*.aab", "*.ipa", "*.xcarchive", "*.dSYM", "*.pyc", "*.class", "*.log", "*.tsbuildinfo"]

    /// Catalog entries that exist on this Mac, with sizes.
    static func scanCatalog() async -> [JunkLocation] {
        let present = catalog.filter(\.exists)
        let sizes = await du(present.map(\.path))
        return present.compactMap { loc in
            var l = loc; l.size = sizes[loc.path] ?? 0
            return l.size > 0 ? l : nil
        }
    }

    /// Project junk under the user's scan roots (dirs are pruned so node_modules isn't walked).
    static func scanProjects(roots: [String]) async -> [JunkItem] {
        var items: [JunkItem] = []
        for root in roots where FileManager.default.fileExists(atPath: root) {
            var args = [root, "-not", "-path", "*/.git/*", "("]
            var first = true
            for d in projectDirs { if !first { args.append("-o") }; first = false; args += ["-type", "d", "-name", d] }
            for f in projectFiles { args += ["-o", "-type", "f", "-name", f] }
            args += [")", "-prune", "-print"]
            guard let out = try? await ProcessRunner.run("/usr/bin/find", args) else { continue }
            let paths = out.stdout.split(separator: "\n").map(String.init).filter { path in
                // bin/obj only count when a .csproj/.sln is nearby (otherwise they're real folders)
                let url = URL(fileURLWithPath: path)
                return !(["bin", "obj"].contains(url.lastPathComponent) && !isDotNetProject(url.deletingLastPathComponent().path))
            }
            let sizes = await du(paths)
            for path in paths {
                let url = URL(fileURLWithPath: path)
                items.append(JunkItem(path: path, name: url.lastPathComponent, size: sizes[path] ?? 0, parent: url.deletingLastPathComponent().path))
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    private static func isDotNetProject(_ dir: String) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: dir))?.contains { $0.hasSuffix(".csproj") || $0.hasSuffix(".sln") || $0.hasSuffix(".fsproj") } ?? false
    }

    /// One `du` call for many paths (batched — a single process is far faster than one per path).
    static func du(_ paths: [String]) async -> [String: Int64] {
        var result: [String: Int64] = [:]
        for chunk in stride(from: 0, to: paths.count, by: 200).map({ Array(paths[$0..<min($0 + 200, paths.count)]) }) {
            guard let out = try? await ProcessRunner.run("/usr/bin/du", ["-sk"] + chunk) else { continue }
            for line in out.stdout.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                if parts.count == 2, let kb = Int64(parts[0]) { result[String(parts[1])] = kb * 1024 }
            }
        }
        return result
    }

    /// Move to Trash; returns paths that failed.
    @discardableResult
    static func trash(_ paths: [String]) -> [String] {
        paths.filter { (try? FileManager.default.trashItem(at: URL(fileURLWithPath: $0), resultingItemURL: nil)) == nil }
    }

    /// External tools with their own cleanup commands (run in the embedded terminal).
    static let toolCommands: [(label: String, note: String, executable: String, args: [String])] = [
        ("Docker: prune images, containers, build cache", "docker system prune -a --volumes", "/usr/local/bin/docker", ["system", "prune", "-a", "--volumes"]),
        ("Xcode: delete unavailable simulators", "xcrun simctl delete unavailable", "/usr/bin/xcrun", ["simctl", "delete", "unavailable"]),
        ("Homebrew: cleanup old versions", "brew cleanup --prune=all", "/opt/homebrew/bin/brew", ["cleanup", "--prune=all"]),
        ("Flutter: clear pub cache", "dart pub cache clean", "/opt/homebrew/bin/dart", ["pub", "cache", "clean"]),
        ("Gradle: stop daemons", "gradle --stop", "/opt/homebrew/bin/gradle", ["--stop"]),
        ("npm: verify & gc cache", "npm cache clean --force", "/opt/homebrew/bin/npm", ["cache", "clean", "--force"]),
    ]
}
