#!/bin/bash
set -euo pipefail

# resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

ELECTRON="$WORK_DIR/native/node_modules/electron/dist/electron"
APP="$WORK_DIR/app"

# Ensure Bun-installed CLIs are discoverable even from desktop launchers.
export PATH="$HOME/.bun/bin:$PATH"

# find codex cli
if [ -n "${CODEX_CLI_PATH:-}" ]; then
  CODEX_CLI="$CODEX_CLI_PATH"
elif command -v codex >/dev/null 2>&1; then
  CODEX_CLI="$(command -v codex)"
else
  CODEX_CLI="$(find "$HOME/.bun/install/global/node_modules/@openai/codex/vendor" -type f -name codex 2>/dev/null | head -n 1 || true)"
fi

if [ ! -f "$ELECTRON" ]; then
  echo "Electron not found. Run ./setup.sh first."
  exit 1
fi

if [ -z "${CODEX_CLI:-}" ] || [ ! -x "$CODEX_CLI" ]; then
  cat <<EOF
Unable to locate the Codex CLI binary.

Install the CLI and retry:
  bun install -g @openai/codex

Or set an explicit path:
  CODEX_CLI_PATH=/absolute/path/to/codex ./run.sh
EOF
  exit 1
fi

export ELECTRON_FORCE_IS_PACKAGED=1
export CODEX_BUILD_NUMBER=571
export CODEX_BUILD_FLAVOR=prod
export BUILD_FLAVOR=prod
export NODE_ENV=production
export CODEX_CLI_PATH="$CODEX_CLI"
export ELECTRON_RENDERER_URL="file://$APP/webview/index.html"
export PWD="$APP"

exec "$ELECTRON" "$APP" --enable-logging --no-sandbox "$@"
