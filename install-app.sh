#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

LAUNCHER_PATH="$LOCAL_BIN_DIR/lin-codex"
DESKTOP_FILE_PATH="$DESKTOP_DIR/lin-codex.desktop"
ICON_TARGET_PATH="$ICON_DIR/lin-codex.png"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

if [ ! -f "$SCRIPT_DIR/run.sh" ]; then
  fail "run.sh not found in $SCRIPT_DIR."
fi

mkdir -p "$LOCAL_BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
chmod +x "$SCRIPT_DIR/run.sh"

cat > "$LAUNCHER_PATH" <<EOF
#!/bin/sh
exec "$SCRIPT_DIR/run.sh" "\$@"
EOF
chmod +x "$LAUNCHER_PATH"
info "Created launcher: $LAUNCHER_PATH"

ICON_SOURCE=""
for candidate in \
  "$SCRIPT_DIR/work/app/assets/icon.png" \
  "$SCRIPT_DIR/work/app/resources/icon.png" \
  "$SCRIPT_DIR/work/app/icon.png"; do
  if [ -f "$candidate" ]; then
    ICON_SOURCE="$candidate"
    break
  fi
done

if [ -z "$ICON_SOURCE" ] && [ -d "$SCRIPT_DIR/work" ]; then
  ICON_SOURCE="$(find "$SCRIPT_DIR/work" -type f -iname "*icon*.png" | head -n 1 || true)"
fi

ICON_VALUE="utilities-terminal"
if [ -n "$ICON_SOURCE" ] && [ -f "$ICON_SOURCE" ]; then
  cp -f "$ICON_SOURCE" "$ICON_TARGET_PATH"
  ICON_VALUE="$ICON_TARGET_PATH"
  info "Installed icon: $ICON_TARGET_PATH"
else
  warn "Could not find a PNG icon in work/. Using fallback icon."
fi

cat > "$DESKTOP_FILE_PATH" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Codex
GenericName=AI Coding Assistant
Comment=Run Codex Desktop on Linux
Exec=$LAUNCHER_PATH %U
Icon=$ICON_VALUE
Terminal=false
Categories=Development;Utility;
StartupNotify=true
StartupWMClass=Codex
Path=$SCRIPT_DIR
EOF
info "Installed desktop entry: $DESKTOP_FILE_PATH"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo ""
info "Done. Search for \"Codex\" in your app launcher."
echo "If it does not appear immediately on Hyprland, log out/in or restart your launcher (wofi/rofi)."
