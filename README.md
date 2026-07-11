# LimitLens — AI Coding Usage Tracker for macOS

> **Track your AI coding assistant usage and quotas in the macOS menu bar.** LimitLens is a native, lightweight macOS menu bar app that monitors usage limits, reset windows, billing cycles, and renewal dates for Codex, Cursor, Devin, and OpenCode Go — all in one glance.

[![Swift 6.0](https://img.shields.io/badge/swift-6.0-orange.svg)](https://swift.org)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://apple.com/macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Tests: 104](https://img.shields.io/badge/tests-104-brightgreen.svg)](#testing)

![LimitLens popover overview showing AI coding usage for Codex, Cursor, Devin, and OpenCode Go with progress bars, billing info, and pace projections](docs/screenshots/popover-overview.png)

---

## Table of Contents

- [Overview](#overview)
- [Supported Providers](#supported-providers)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Development](#development)
- [Testing](#testing)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

LimitLens is a **native macOS menu bar app** (no Dock icon) that aggregates usage data from multiple AI coding assistants into a single, color-coded popover. It runs quietly in the background, fetching usage data on a configurable interval and rendering live progress rings, countdown timers, and detailed metrics directly in your menu bar.

**Who is it for?** Developers who use multiple AI coding tools and want to avoid hitting rate limits or billing surprises. LimitLens gives you a single dashboard to monitor all of them at once.

**Key design principles:**
- **No accounts, no cloud, no telemetry** — everything runs locally on your Mac
- **Native Swift/SwiftUI** — not Electron, not a web wrapper
- **Privacy-first** — provider names can be hidden throughout the UI
- **Zero-config** — auto-detects installed providers on first launch

---

## Supported Providers

| Provider | What it tracks |
|----------|---------------|
| **Codex** (OpenAI) | Rate limits (primary/secondary windows), reset credits with per-credit expiry, token usage, daily streaks |
| **Cursor** | Plan usage in dollars, auto/API sub-limits, billing cycle, plan type |
| **Devin** (Windsurf) | Daily & weekly quota bars, overage balance, plan cycle, multi-tier local cache |
| **OpenCode Go** | Rolling / weekly / monthly usage windows, billing balance, card info, payment history |

Each provider can be individually enabled or disabled. Disabled providers are not fetched and do not appear in the menu bar.

---

## Features

### Core Usage Tracking
- **Multi-provider dashboard** — monitor Codex, Cursor, Devin, and OpenCode Go in one place
- **Live progress rings** — color-coded usage arcs in the menu bar (green → orange → red)
- **Countdown timers** — time-remaining text that updates every minute without re-fetching
- **Billing cycle tracking** — renewal dates with urgency coloring (red/orange/yellow/green)
- **Reset credit monitoring** — per-credit expiry tracking for Codex reset credits
- **Token usage metrics** — lifetime tokens, peak daily, current streaks

### Menu Bar Display Modes
Three display modes, configurable from Settings:

- **Logos** — colored progress rings with provider icons inside. Each ring shows usage as a clockwise arc: green/blue gradients for low usage (< 50%), orange for moderate (50–70%), red for critical (≥ 70%)
- **Countdowns** — compact pills with time-remaining text (e.g. `1h30m`, `2d`, `now`) and progress-based colored borders that fill from left to right as usage grows
- **Hidden** — anonymizes all provider names to "Provider 1" through "Provider 4" throughout the UI, help text, and error messages. Menu bar icons switch to a generic symbol

When a provider fetch fails but cached data exists, the indicator shows a **stale** state with an orange badge and the cached severity level.

### Notifications (macOS native)
LimitLens uses native macOS notifications (UserNotifications framework) to alert you about important usage events. No push servers, no cloud — all notifications are scheduled locally.

| Notification | Trigger | Configurable |
|-------------|---------|-------------|
| **Critical usage** | Usage crosses the critical threshold (default 90%) | Per-provider custom threshold |
| **Billing expiring** | Plan renewal within 7 days | Toggle on/off |
| **Provider unavailable** | Provider fetch fails | Toggle on/off |
| **Daily digest** | Once per day at a configured hour | Toggle + hour picker |

Additional notification options:
- **Per-provider toggles** — enable/disable notifications for each provider independently
- **Custom per-provider thresholds** — set custom critical usage percentages per provider (e.g. notify when Codex hits 50% but only when Cursor hits 90%)
- **Quiet hours** — suppress all notifications during specified hours (e.g. 22:00–07:00)
- **Test notification button** — verify macOS notification permissions are granted

### Usage Pace Projection
LimitLens computes a **linear projection** of your usage pace by comparing two consecutive usage snapshots. This tells you whether you're on track to exhaust your quota before the reset window, or if you'll reset with usage to spare.

- **"On track to exhaust in ~3h"** — your current pace will exhaust the quota before reset (shown in orange)
- **"On pace to reset with ~15% to spare"** — your usage is sustainable through the reset window
- **"Usage stable"** — usage is not increasing or is declining
- **"Collecting pace data..."** — shown after the first sample while waiting for a second sample to compute the projection

The projection requires at least 30 seconds between samples and updates on every refresh cycle.

### Provider Health Diagnostics
A dedicated diagnostics section in Settings helps troubleshoot connection issues:

- **Status dot** — green (connected), red (failed), orange (path missing), gray (idle/disabled)
- **Last fetch** — timestamp of the most recent successful fetch
- **Path validation** — checks if configured executable or database paths exist on disk
- **Last error** — shows the most recent error message per provider
- **Test connection** — button to manually trigger a fetch and report success/failure with elapsed time in milliseconds

### Refresh Configuration
- **Configurable refresh interval** — 1m, 3m, 5m, 15m, 30m, or custom (1–60 min)
- **Retry on failure** — automatic retry with configurable max attempts
- **Per-provider refresh** — refresh individual providers on demand
- **System wake handling** — clears stuck refresh state after sleep/wake

### Settings & Configuration
- **Auto-detection** — detects installed providers on first launch
- **Custom paths** — configure executable and database paths per provider
- **File picker integration** — browse for files directly from Settings
- **Automatic persistence** — settings save to disk automatically
- **Reset to defaults** — one-click reset button
- **Corrupt config recovery** — invalid configs are backed up and replaced with defaults

### Severity System

Menu bar indicators use four severity levels, derived from usage percentage:

| Severity | Threshold | Ring color | Countdown pill color |
|----------|-----------|------------|---------------------|
| Unavailable | No data | Gray slash | Gray pill |
| Healthy | < 70% | Provider gradient | Provider color |
| Warning | 70–89% | Orange | Orange |
| Critical | ≥ 90% | Red | Red |

---

## Installation

### Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 6.0 toolchain

### Run from source

```sh
git clone https://github.com/sebbonit/AiStat.git
cd AiStat

# Run directly from SwiftPM
swift run LimitLens
```

### Build the app bundle

```sh
Scripts/build-app.sh
open .build/LimitLens.app
```

This builds the release binary and creates a standalone `.app` bundle with the bundled LimitLens icon that you can drag to your Applications folder.

---

## Configuration

On first launch, LimitLens auto-detects which providers have valid paths and enables only those. You can adjust everything from the Settings tab.

### Configuration file

Settings are persisted to:

```
~/Library/Application Support/LimitLens/config.json
```

If the file becomes corrupted, it is renamed to `config.invalid.json` and defaults are loaded.

### OpenCode Go setup

OpenCode Go usage is scraped from the web dashboard because the CLI token does not expose usage windows. On first launch, LimitLens shows Settings the first time you open the popover, with an OpenCode Go dashboard form.

You will need:
- Your workspace ID from a URL like `https://opencode.ai/workspace/<workspace-id>/go`
- The browser cookie named `auth` for `opencode.ai`

The form writes `~/.config/opencode/opencode-quota/opencode-go.json`, enables OpenCode Go, and refreshes usage. `Scripts/configure-opencode-go.sh` remains available for terminal setup.

---

## Architecture

### Modules

| Module | Type | Purpose |
|--------|------|---------|
| `LimitLens` | Executable | SwiftUI app, menu bar rendering, configuration UI, notifications |
| `LimitLensCore` | Library | Provider clients, API models, usage formatting, pace projection |

### Data flow

```
User launches LimitLens
        │
        ▼
UsageViewModel.start()
        │
        ├─► Refresh loop (configurable interval, default 5 min)
        │       │
        │       ├─► CodexAppServerClient  ──► codex binary (JSON-RPC over stdio)
        │       ├─► BackendCodexAccountClient  ──► chatgpt.com API
        │       ├─► BackendResetCreditClient   ──► chatgpt.com API
        │       ├─► CursorUsageClient     ──► cursor.sh API (via SQLite auth)
        │       ├─► DesktopQuotaClient    ──► codeium.com / local protobuf / SQLite
        │       └─► OpenCodeGoUsageClient ──► opencode.ai dashboard (HTML scraping)
        │
        ├─► Notification coordinator
        │       └─► Evaluates usage summaries + billing → delivers macOS notifications
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

### Project structure

```
AiStat/
├── Package.swift
├── Sources/
│   ├── LimitLens/               # App target
│   │   ├── LimitLensApp.swift          # @main, MenuBarExtra entry point
│   │   ├── LimitLensPopover.swift      # Popover with tab bar and content switching
│   │   ├── UsageViewModel.swift        # State management, refresh loops, diagnostics
│   │   ├── UsageViewModel+MenuBar.swift # Menu bar status derivation
│   │   ├── UsageViewModel+Summary.swift # Provider summary aggregation
│   │   ├── LimitLensConfiguration.swift       # Config models, auto-detect, migration
│   │   ├── LimitLensConfigurationStore.swift  # JSON persistence
│   │   ├── SettingsSection.swift       # Settings tab UI (providers, refresh, notifications, diagnostics)
│   │   ├── OverviewSection.swift       # Overview tab with all-provider summary
│   │   ├── CodexSection.swift          # Codex provider tab
│   │   ├── CursorSection.swift         # Cursor provider tab
│   │   ├── DevinSection.swift          # Devin provider tab
│   │   ├── OpenCodeGoSection.swift     # OpenCode Go provider tab
│   │   ├── SharedViews.swift           # Shared UI components (PaceProjectionLine, StatusLine, etc.)
│   │   ├── UsageNotifications.swift    # Notification coordinator and delivery
│   │   ├── MenuBarStatusModels.swift   # Menu bar status types and diagnostic models
│   │   ├── MenuBarStatusLabel.swift    # Menu bar label view
│   │   └── MenuBarStatusImageRenderer.swift # NSImage rendering for menu bar
│   └── LimitLensCore/           # Library target
│       ├── CodexAppServerClient.swift        # Codex JSON-RPC over stdio
│       ├── BackendCodexAccountClient.swift    # Codex account/renewal API
│       ├── BackendResetCreditClient.swift     # Codex reset credits API
│       ├── CodexModels.swift                  # Shared models across all providers
│       ├── CodexUsageError.swift              # Error types
│       ├── CursorUsageClient.swift            # Cursor API + SQLite auth
│       ├── DesktopQuotaClient.swift           # Devin protobuf + SQLite
│       ├── OpenCodeGoUsageClient.swift        # OpenCode dashboard scrapers
│       ├── UsageFormatting.swift              # Time, money, number formatting
│       └── UsagePaceProjection.swift          # Linear pace projection logic
├── Tests/
│   ├── LimitLensTests/
│   │   ├── MenuBarStatusTests.swift           # Menu bar display mode tests
│   │   ├── UsageNotificationTests.swift       # Notification coordinator tests
│   │   ├── LimitLensConfigurationTests.swift  # Config persistence + migration tests
│   │   ├── ProviderDiagnosticsTests.swift     # Provider diagnostics tests
│   │   └── UsageViewModelTests.swift          # View model + pace projection tests
│   └── LimitLensCoreTests/
│       ├── LimitLensCoreTests.swift           # Parsing + formatting tests
│       ├── UsagePaceProjectionTests.swift     # Pace projection unit tests
│       └── Fixtures/                          # JSON/HTML test fixtures
├── docs/
│   └── screenshots/                           # Screenshots for README
├── Resources/
│   ├── Info.plist
│   ├── LimitLens.icns
│   └── LimitLensIcon.png          # High-resolution app icon master
├── Scripts/
│   ├── build-app.sh                # Build .app bundle
│   └── configure-opencode-go.sh    # Terminal fallback for OpenCode Go config
├── AGENTS.md                       # Agent guidelines
└── README.md
```

---

## Testing

LimitLens includes 104 tests across 8 test suites:

| Suite | Tests | Covers |
|-------|-------|--------|
| Core parsing & formatting | ~25 | JSON fixtures for all four providers, HTML scraping, protobuf decoding, billing parsing |
| Usage pace projection | 8 | Exhaustion projection, stable usage, spare calculation, short elapsed |
| Menu bar status indicators | 12 | Loading/warning/critical/stale/unavailable states, privacy mode, countdown mode |
| Notification coordinator | 20+ | Critical usage, billing, unavailable, per-provider thresholds, daily digest, quiet hours |
| LimitLens configuration | 15+ | Save/reload, auto-detection, legacy migration, bad JSON, daily digest clamping |
| Refresh configurability | 5+ | Interval changes, retry, per-provider refresh gating, overlap prevention |
| Provider diagnostics | 2 | Connection test success/failure results |
| Dashboard deep links | 3 | Tab navigation from overview |

```sh
swift test
```

---

## FAQ

**Does LimitLens send any data to a server?**
No. LimitLens runs entirely locally. It fetches usage data directly from provider APIs and dashboards using credentials already on your machine. No telemetry, no analytics, no phone-home.

**Does LimitLens store my passwords or tokens?**
LimitLens reads auth tokens from existing locations (e.g. `~/.codex/auth.json`, Cursor's SQLite database) but does not store or transmit them. The only thing saved to disk is your configuration file at `~/Library/Application Support/LimitLens/config.json`.

**Why does OpenCode Go require a cookie?**
The OpenCode Go CLI token does not expose usage windows. LimitLens scrapes the web dashboard, which requires the `auth` cookie from your browser session. This cookie is stored locally and never transmitted anywhere except opencode.ai.

**Can I hide provider names for screenshots?**
Yes. Enable "Hidden" display mode in Settings to anonymize all provider names to "Provider 1–4" throughout the UI, help text, and error messages.

**How do I report a bug or request a feature?**
Open an issue on [GitHub](https://github.com/sebbonit/AiStat/issues).

---

## Contributing

Pull requests are welcome. Please keep commits focused, add tests for new behavior, and verify with `swift test` before opening a PR.

### Adding a new provider

1. Create a client conforming to an async fetch protocol in `Sources/LimitLensCore/`
2. Add models and parsing logic with JSON/HTML fixtures in `Tests/LimitLensCoreTests/Fixtures/`
3. Add a `ProviderTab` case and a section view in `Sources/LimitLens/`
4. Wire up the view model refresh path and notification coordinator
5. Add tests in both `LimitLensTests` and `LimitLensCoreTests`

---

## License

MIT
