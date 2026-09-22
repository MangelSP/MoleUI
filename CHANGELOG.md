# Changelog

All notable changes to MoleUI. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow [SemVer](https://semver.org/).

## [1.5.0] — 2026-09-21

### Added
- **Dev Junk** tab in Analyze: tree of developer junk with sizes, checkboxes and
  multi-select → Trash. Covers tool caches (Gradle, Maven, pub-cache, npm/yarn/pnpm,
  Playwright, NuGet, pip/uv, CocoaPods, Homebrew, Go, Cargo), Android AVDs & system
  images, Xcode DerivedData / Archives / device support / simulators, AI-tool data
  (Claude Code, Claude Desktop, Codex, Cursor, Antigravity, Gemini, Orca, VS Code,
  JetBrains) and per-project build output (`node_modules`, `.next`, `dist`, `build`,
  `target`, `.dart_tool`, `Pods`, `bin`/`obj`, `__pycache__`, `.venv`, `*.apk`, `*.aab`,
  `*.ipa`, `*.xcarchive`, `*.dSYM`…). *review* badge on slow-to-rebuild items, *Select
  all safe*, and one-click `docker system prune` / `simctl delete unavailable` /
  `brew cleanup` / `dart pub cache clean` / `gradle --stop` / `npm cache clean`.
- Fan card: **Silent / Auto / Full** thermal profile via macOS power modes (`pmset`).

### Changed
- Dashboard cards share one height — 4×2 grid lines up.
- `scripts/genproj.py` now emits the SwiftTerm package reference.

### Fixed
- `Info.plist` version/build were stuck at 1.2.0/3.

## [1.4.0] — 2026-09-21

### Added
- **Embedded terminal** (SwiftTerm): `mo clean` / `purge` / `optimize` / `installer` run
  inside the app with their TUI and sudo prompt; per-command options and an
  `--external` volume picker. Terminal.app hand-off kept as fallback.
- **Apps** screen: installed apps with sizes → `mo uninstall` (leftovers included).
- **History** screen: `mo history --json` sessions.
- **Touch ID for sudo** toggle in About.
- **Pixel cat mascot** in the sidebar, menu bar and loading states; reacts to system
  pressure, click to pet; three skins; can be disabled in Automation.
- Cat-voiced threshold notifications and a *Send test* button.

### Fixed
- History decoding (double snake_case conversion) and empty-state layout.

## [1.3.0] — 2026-09-21

### Added
- **Processes** screen: all processes by resident memory, group by `.app` bundle,
  search, pin to top, detail sheet, context menu, restart app, Stop / Force Kill.
  System processes flagged; killing another user's process escalates through macOS's
  admin dialog.
- **CPU History** card (total + per-core sparklines) on Dashboard and Processes.
- `Sparkline` fixed-range option.

## [1.2.0] — 2026-08-18

### Added
- Free RAM (native `purge` via admin prompt) from the Memory card and menu bar.
- Optimize as a menu-bar quick action.

### Fixed
- Dashboard loading / error states now fill the content area.

## [1.1.0] — 2026-08-17

### Added
- Automation: threshold notifications (CPU / RAM / disk / temp) and a scheduled,
  confirm-first cleanup job.
- Network screen: per-app bandwidth (`nettop`) with connections & kill; interfaces.
- Ports screen: listening ports with per-process detail and kill.
- Battery / GPU / Fan cards and laptop info; rich process inspector.
- Menu-bar monitor, JSON snapshot export, app icon.

### Changed
- Dashboard redesigned as a dense monitor UI (emerald theme, mono labels, core
  histogram, sparklines, gradient meters).

## [1.0.0] — 2026-08-17

- Initial release: native SwiftUI front end for the [Mole](https://github.com/tw93/mole)
  CLI — Dashboard, Disk Analyzer, Maintenance previews, onboarding.

[1.5.0]: https://github.com/MangelSP/MoleUI/releases/tag/v1.5.0
[1.4.0]: https://github.com/MangelSP/MoleUI/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/MangelSP/MoleUI/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/MangelSP/MoleUI/releases/tag/v1.2.0
[1.1.0]: https://github.com/MangelSP/MoleUI/releases/tag/v1.1.0
[1.0.0]: https://github.com/MangelSP/MoleUI/commit/6064402
