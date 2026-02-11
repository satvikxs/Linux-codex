#!/bin/bash
set -euo pipefail

# resolve paths relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"

ELECTRON="$WORK_DIR/native/node_modules/electron/dist/electron"
APP="$WORK_DIR/app"

# find codex cli
if [ -n "${CODEX_CLI_PATH:-}" ]; then
  CODEX_CLI="$CODEX_CLI_PATH"
elif command -v codex >/dev/null 2>&1; then
  CODEX_CLI="$(command -v codex)"
else
  CODEX_CLI="$HOME/.bun/install/global/node_modules/@openai/codex/vendor/x86_64-unknown-linux-musl/codex/codex"
fi

if [ ! -f "$ELECTRON" ]; then
  echo "Electron not found. Run ./setup.sh first."
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
