# ResetStat Runbook

ResetStat is a native macOS menu bar app built with Swift Package Manager. It targets macOS 13 or newer.

## Run Locally

From the repo root:

```sh
swift run ResetStat
```

This starts the menu bar app directly from SwiftPM. Look for the `S` icon in the macOS menu bar. The app has no Dock icon.

## Configure Providers

On first launch, ResetStat auto-detects common provider paths and enables only the providers it finds. Open the menu bar popover and click the gear icon in the footer to change settings.

Settings are saved automatically to:

```text
~/Library/Application Support/ResetStat/config.json
```

You can:

- enable or disable Codex, Cursor, Devin, and OpenCode Go
- set the Codex executable path
- set Cursor and Devin `state.vscdb` paths
- configure OpenCode Go dashboard auth or set a custom config path
- hide provider names
- reset all settings to defaults

Disabled providers are not fetched, do not appear in the overview, and do not appear in the menu bar status rings.

## Test

```sh
swift test
```

## Build the Executable

```sh
swift build -c release
```

The release executable is written under SwiftPM's release build directory. You can inspect the path with:

```sh
swift build -c release --show-bin-path
```

## Build the `.app` Bundle

```sh
Scripts/build-app.sh
```

This generates the icon, builds the release binary, and creates:

```text
.build/ResetStat.app
```

Launch it with:

```sh
open .build/ResetStat.app
```

## OpenCode Go Setup

OpenCode Go usage is scraped from the OpenCode dashboard, because the CLI token does not expose the dashboard usage windows. On first launch, ResetStat shows Settings the first time you open the popover, with an OpenCode Go dashboard form.

You will need:

- workspace id from a URL like `https://opencode.ai/workspace/<workspace-id>/go`
- browser cookie value named `auth` for `opencode.ai`

The form writes:

```text
~/.config/opencode/opencode-quota/opencode-go.json
```

It enables OpenCode Go and refreshes usage after saving.

You can also point ResetStat to a different OpenCode Go config file from the Settings tab. `Scripts/configure-opencode-go.sh` remains available for terminal setup.
