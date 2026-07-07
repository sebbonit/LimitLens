# ResetStat

A native macOS menu bar app that tracks your AI coding assistant usage across multiple providers in one glance. No Dock icon — just quiet, color-coded rings and countdowns in your menu bar.

[![Swift 6.0](https://img.shields.io/badge/swift-6.0-orange.svg)](https://swift.org)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://apple.com/macos)

<img src="Resources/ResetStat.icns" width="96" height="96" alt="ResetStat icon" />

---

## Providers

ResetStat connects to four AI coding tools and displays their usage limits, reset windows, billing cycles, and renewal dates.

| Provider | What it tracks |
|----------|---------------|
| **Codex** (OpenAI) | Rate limits (primary/secondary windows), reset credits with per-credit expiry, token usage, daily streaks |
| **Cursor** | Plan usage in dollars, auto/API sub-limits, billing cycle, plan type |
| **Devin** (Windsurf) | Daily & weekly quota bars, overage balance, plan cycle, multi-tier local cache |
| **OpenCode Go** | Rolling / weekly / monthly usage windows, billing balance, card info, payment history |

Each provider can be individually enabled or disabled. Disabled providers are not fetched and do not appear in the menu bar.

---

## Menu Bar Display Modes

The menu bar indicators support three display modes, configurable from Settings:

### Logos
Colored progress rings with provider icons inside. Each ring shows usage as a clockwise arc:
- **Green/blue gradients** for low usage (< 50%)
- **Orange** for moderate usage (50–70%)
- **Red** for critical usage (≥ 70%)

### Countdowns
Compact pills with time-remaining text (e.g. `1h30m`, `2d`, `now`) and progress-based colored borders that fill from left to right as usage grows.

### Hidden
Anonymizes all provider names to "Provider 1" through "Provider 4" throughout the UI, help text, and error messages. Menu bar icons switch to a generic symbol.

---

## Popover

Click the ResetStat menu bar icon to open the 460px-wide popover.

### Overview
A glance at all enabled providers: usage percentages, reset countdowns, severity summaries. A billing grid shows renewal dates with urgency coloring (red = expired, orange = within 7 days, yellow = within 15 days, green = healthy).

### Provider Tabs
Each enabled provider gets its own tab with graphs, progress bars, and detailed metrics.

### Settings
- Enable/disable providers individually
- Set custom paths for executables and state databases
- Choose menu bar display mode (Logos / Countdowns / Hidden)
- Reset all settings to defaults
- Settings save automatically to disk

---

## Installation

### Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 6.0 toolchain

### Run from source

```sh
git clone https://github.com/anomalyco/resetstat.git
cd resetstat

# Run directly from SwiftPM
swift run ResetStat
```

### Build the app bundle

```sh
Scripts/build-app.sh
open .build/ResetStat.app
```

This generates the icon, builds the release binary, and creates a standalone `.app` bundle you can drag to your Applications folder.

---

## Configuration

On first launch, ResetStat auto-detects which providers have valid paths and enables only those. You can adjust everything from the Settings tab.

### Configuration file

Settings are persisted to:

```
~/Library/Application Support/ResetStat/config.json
```

If the file becomes corrupted, it is renamed to `config.invalid.json` and defaults are loaded.

### OpenCode Go setup

OpenCode Go usage is scraped from the web dashboard because the CLI token does not expose usage windows. On first launch, ResetStat shows Settings the first time you open the popover, with an OpenCode Go dashboard form.

You will need:
- Your workspace ID from a URL like `https://opencode.ai/workspace/<workspace-id>/go`
- The browser cookie named `auth` for `opencode.ai`

The form writes `~/.config/opencode/opencode-quota/opencode-go.json`, enables OpenCode Go, and refreshes usage. `Scripts/configure-opencode-go.sh` remains available for terminal setup.

---

## Usage Formatting Reference

The app uses `UsageFormatting` from `ResetStatCore` to format all times and amounts:

| Function | Example output |
|----------|---------------|
| `timeRemainingText(date:)` | `3h 15m`, `2d 5h`, `now`, `Unknown` |
| `compactCountdownText(date:)` | `3h15m`, `1d`, `20m`, `now`, `?` |
| `resetText(date:)` | `Jul 14, 3:45 PM` |
| `relativeDayText(date:)` | `tomorrow`, `in 5d`, `later today` |
| `usd(cents:)` / `usd(micros:)` | `$20`, `$12.34`, `--` |
| `compactNumber(_:)` | `1,234,567` |

Expiry urgency thresholds:
- **Expired**: date in the past
- **Soon**: within 7 days
- **Warning**: 8–15 days
- **Healthy**: 15+ days
- **Unknown**: no date available

Usage severity thresholds:
- **Critical**: ≥ 90% used
- **Warning**: ≥ 70% used
- **Healthy**: < 70% used
- **Unavailable**: no data or provider disabled

---

## Architecture

### Modules

| Module | Type | Purpose |
|--------|------|---------|
| `ResetStat` | Executable | SwiftUI app, menu bar rendering, configuration UI |
| `ResetStatCore` | Library | Provider clients, API models, usage formatting |

### Data flow

```
User launches ResetStat
        │
        ▼
UsageViewModel.start()
        │
        ├─► Refresh loop (every 5 min)
        │       │
        │       ├─► CodexAppServerClient  ──► codex binary (JSON-RPC over stdio)
        │       ├─► BackendCodexAccountClient  ──► chatgpt.com API
        │       ├─► BackendResetCreditClient   ──► chatgpt.com API
        │       ├─► CursorUsageClient     ──► cursor.sh API (via SQLite auth)
        │       ├─► DesktopQuotaClient    ──► codeium.com / local protobuf / SQLite
        │       └─► OpenCodeGoUsageClient ──► opencode.ai dashboard (HTML scraping)
        │
        └─► Clock loop (every 1 min)
                └─► Updates @Published now for live countdowns
```

### Provider details

**Codex** — Launches the local `codex` binary in `app-server --stdio` mode and communicates via JSON-RPC over stdin/stdout. Backend APIs (`accounts/check`, reset credits) are called over HTTPS using the auth token from `~/.codex/auth.json`.

**Cursor** — Reads the auth token from the Cursor SQLite state database via the `sqlite3` CLI, then calls the Cursor gRPC-Transcoding API at `api2.cursor.sh`. Handles auto/api split limits and billing cycle tracking.

**Devin** — Uses a three-tier fallback strategy: remote protobuf API at `server.codeium.com`, local Devin language server (discovered via `ps`/`lsof`), and a local SQLite cache. Includes a hand-rolled minimal protobuf parser to avoid external dependencies.

**OpenCode Go** — Scrapes the OpenCode dashboard HTML, supporting both SolidJS reactive store (`$R[]`) and `data-slot` attribute formats. Billing is scraped from a separate billing page. Auth is read from a local JSON config or environment variables.

### Concurrency

- `UsageViewModel` is `@MainActor` for safe SwiftUI binding
- Provider clients use `async`/`await` and are `@unchecked Sendable`
- All enabled providers are fetched in parallel via `withTaskGroup`
- Refresh calls are gated with an `isRefreshing` flag to prevent overlap
- The menu bar image is rendered into an `NSImage` via `lockFocus()` / `unlockFocus()` with explicit `NSGraphicsContext` save/restore for clip operations

---

## Development

### Build

```sh
# Debug build
swift build

# Release build
swift build -c release

# Show release binary path
swift build -c release --show-bin-path
```

### Test

```sh
# Run all tests
swift test
```

Tests cover:
- **Core parsing**: JSON fixtures for all four providers, HTML scraping, protobuf decoding, billing parsing
- **Menu bar status**: loading/warning/critical/stale/unavailable states, privacy mode, countdown mode, disabled providers
- **Configuration**: save/reload, auto-detection, legacy migration, bad JSON handling, validation

### Project structure

```
ResetStat/
├── Package.swift
├── Sources/
│   ├── ResetStat/               # App target
│   │   ├── ResetStatApp.swift   # @main, popover UI, menu bar renderer
│   │   ├── ViewModels.swift     # UsageViewModel, state management
│   │   ├── ResetStatConfiguration.swift       # Config models, auto-detect, migration
│   │   └── ResetStatConfigurationStore.swift  # JSON persistence
│   └── ResetStatCore/           # Library target
│       ├── CodexAppServerClient.swift        # Codex JSON-RPC over stdio
│       ├── BackendCodexAccountClient.swift    # Codex account/renewal API
│       ├── BackendResetCreditClient.swift     # Codex reset credits API
│       ├── CodexModels.swift                  # Shared models across all providers
│       ├── CodexUsageError.swift              # Error types
│       ├── CursorUsageClient.swift            # Cursor API + SQLite auth
│       ├── DesktopQuotaClient.swift           # Devin protobuf + SQLite
│       ├── OpenCodeGoUsageClient.swift        # OpenCode dashboard scrapers
│       └── UsageFormatting.swift              # Time, money, number formatting
├── Tests/
│   ├── ResetStatTests/
│   │   ├── MenuBarStatusTests.swift           # 12 tests, all display modes
│   │   └── ResetStatConfigurationTests.swift  # 8 tests, config + migration
│   └── ResetStatCoreTests/
│       ├── ResetStatCoreTests.swift           # ~25 tests, all parsing + formatting
│       └── Fixtures/                          # JSON/HTML test fixtures
├── Resources/
│   ├── Info.plist
│   └── ResetStat.icns
├── Scripts/
│   ├── build-app.sh                # Build .app bundle
│   ├── configure-opencode-go.sh    # Terminal fallback for OpenCode Go config
│   └── generate-icon.swift         # Generate .icns from source
├── AGENTS.md                       # Agent guidelines
├── RUNBOOK.md                      # Quick reference
└── README.md
```

### Refresh lifecycle

- The view model starts two async loops on launch
- **Refresh loop**: fetches all enabled providers every 5 minutes using `withTaskGroup` for parallelism
- **Clock loop**: updates the `now` property every minute so countdown timers stay accurate without re-fetching
- Disabling a provider clears its cached snapshot and marks its state as `.disabled`

### Severity system

Menu bar indicators use four severity levels, derived from usage percentage:

| Severity | Threshold | Ring color | Countdown pill color |
|----------|-----------|------------|---------------------|
| Unavailable | No data | Gray slash | Gray pill |
| Healthy | < 70% | Provider gradient | Provider color |
| Warning | 70–89% | Orange | Orange |
| Critical | ≥ 90% | Red | Red |

When a provider fetch fails but cached data exists, the indicator shows a **stale** state with an orange badge and the cached severity level.

---

## License

MIT

---

## Contributing

Pull requests are welcome. Please keep commits focused, add tests for new behavior, and verify with `swift test` before opening a PR.
