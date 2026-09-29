#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/opencode-quota"
CONFIG_FILE="$CONFIG_DIR/opencode-go.json"

printf "OpenCode Go dashboard config for LimitLens\n\n"
printf "1. Open https://opencode.ai in your browser.\n"
printf "2. Go to the Go usage dashboard.\n"
printf "3. Copy the workspace id from a URL like:\n"
printf "   https://opencode.ai/console/<workspace-id>/go\n"
printf "4. Copy the browser cookie named __Host-console_session for opencode.ai.\n\n"

read -r -p "Workspace id: " WORKSPACE_ID
if [[ -z "${WORKSPACE_ID// }" ]]; then
  printf "No workspace id provided.\n" >&2
  exit 1
fi

read -r -s -p "auth cookie value: " AUTH_COOKIE
printf "\n"
if [[ -z "${AUTH_COOKIE// }" ]]; then
  printf "No auth cookie provided.\n" >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
python3 - "$CONFIG_FILE" "$WORKSPACE_ID" "$AUTH_COOKIE" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "workspaceId": sys.argv[2].strip(),
    "authCookie": sys.argv[3].strip() if "=" in sys.argv[3] else "__Host-console_session=" + sys.argv[3].strip(),
}
path.write_text(json.dumps(payload, indent=2) + "\n")
path.chmod(0o600)
PY

printf "Wrote %s\n" "$CONFIG_FILE"
printf "Restart LimitLens or click refresh in the menu bar popover.\n"
