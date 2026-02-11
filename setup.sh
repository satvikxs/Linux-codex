#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"
DMG_PATH="${1:-$SCRIPT_DIR/Codex.dmg}"

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# check deps
command -v 7z >/dev/null 2>&1 || fail "7z not found. Install p7zip-full (apt) or p7zip (pacman)."
command -v bun >/dev/null 2>&1 || fail "bun not found. Install from https://bun.sh"

# check dmg
if [ ! -f "$DMG_PATH" ]; then
  fail "Codex.dmg not found at $DMG_PATH\nDownload from https://openai.com/codex and place it in the repo root."
fi

info "Starting Lin-Codex setup..."

# extract dmg
EXTRACTED_DIR="$WORK_DIR/extracted"
if [ -d "$EXTRACTED_DIR/Codex Installer" ]; then
  warn "Already extracted, skipping. Delete work/extracted/ to re-extract."
else
  info "Extracting DMG..."
  mkdir -p "$EXTRACTED_DIR"
  7z x "$DMG_PATH" -o"$EXTRACTED_DIR" -y > /dev/null
  info "DMG extracted."
fi

# locate the app bundle
APP_BUNDLE=$(find "$EXTRACTED_DIR" -name "Codex.app" -type d | head -1)
if [ -z "$APP_BUNDLE" ]; then
  fail "Could not find Codex.app inside extracted DMG."
fi
info "Found app bundle: $APP_BUNDLE"

# extract app.asar
APP_DIR="$WORK_DIR/app"
ASAR_FILE="$APP_BUNDLE/Contents/Resources/app.asar"
ASAR_UNPACKED="$APP_BUNDLE/Contents/Resources/app.asar.unpacked"
if [ -d "$APP_DIR/.vite" ]; then
  warn "App directory already set up, skipping. Delete work/app/ to redo."
else
  if [ ! -f "$ASAR_FILE" ]; then
    fail "app.asar not found in Codex.app bundle."
  fi
  info "Extracting app.asar..."
  bunx asar extract "$ASAR_FILE" "$APP_DIR"

  # overlay unpacked native modules
  if [ -d "$ASAR_UNPACKED" ]; then
    info "Copying unpacked native modules..."
    cp -r "$ASAR_UNPACKED/"* "$APP_DIR/"
  fi
  info "App extracted."
fi

# install electron + native deps
NATIVE_DIR="$WORK_DIR/native"
if [ -d "$NATIVE_DIR/node_modules/electron" ]; then
  warn "Electron already installed, skipping. Delete work/native/ to reinstall."
else
  info "Installing Electron and native dependencies..."
  mkdir -p "$NATIVE_DIR"

  # read electron version from app package.json
  ELECTRON_VERSION=$(grep -o '"electron": "[^"]*"' "$APP_DIR/package.json" 2>/dev/null | head -1 | grep -o '[0-9][0-9.]*' || echo "40.0.0")
  info "Using Electron $ELECTRON_VERSION"

  cat > "$NATIVE_DIR/package.json" <<PKGJSON
{
  "name": "lin-codex-native",
  "version": "1.0.0",
  "private": true,
  "type": "commonjs"
}
PKGJSON

  cd "$NATIVE_DIR"
  bun install "electron@$ELECTRON_VERSION" better-sqlite3 node-pty
  cd "$SCRIPT_DIR"
  info "Electron and native modules installed."
fi

# rebuild native modules for the local electron
info "Rebuilding native modules for Linux..."
ELECTRON_PATH="$NATIVE_DIR/node_modules/electron/dist/electron"
if [ ! -f "$ELECTRON_PATH" ]; then
  fail "Electron binary not found at $ELECTRON_PATH"
fi

ELECTRON_ABI=$(cd "$NATIVE_DIR" && node -e "console.log(require('electron/package.json').version)" 2>/dev/null || echo "$ELECTRON_VERSION")
info "Electron ABI version: $ELECTRON_ABI"

# copy rebuilt native modules into app
info "Linking native modules into app..."
APP_MODULES="$APP_DIR/node_modules"
mkdir -p "$APP_MODULES"

for mod in better-sqlite3 node-pty bindings; do
  if [ -d "$NATIVE_DIR/node_modules/$mod" ]; then
    rm -rf "$APP_MODULES/$mod"
    cp -r "$NATIVE_DIR/node_modules/$mod" "$APP_MODULES/$mod"
  fi
done

info "Native modules linked."

# apply linux shim to main.js if not already patched
MAIN_JS="$APP_DIR/.vite/build/main.js"
if [ -f "$MAIN_JS" ] && ! grep -q "CODEX-LINUX-SHIM" "$MAIN_JS"; then
  info "Applying Linux shim to main.js..."
  SHIM='/* CODEX-LINUX-SHIM */
const path = require("path");
const appDir = path.resolve(__dirname, "../..");
process.env.ELECTRON_RENDERER_URL = process.env.ELECTRON_RENDERER_URL || "file://" + path.join(appDir, "webview", "index.html");
'
  TEMP_MAIN=$(mktemp)
  echo "$SHIM" > "$TEMP_MAIN"
  cat "$MAIN_JS" >> "$TEMP_MAIN"
  mv "$TEMP_MAIN" "$MAIN_JS"
  info "Linux shim applied."
else
  warn "Linux shim already present or main.js not found, skipping."
fi

echo ""
info "Setup complete! Run ./run.sh to launch Codex."
echo ""
echo "  If you haven't already, install the Codex CLI:"
echo "    bun install -g @openai/codex"
echo ""
