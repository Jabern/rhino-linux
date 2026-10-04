#!/usr/bin/env bash
# deploy-rhino.sh — Automated prefix deployment & configuration for Rhinoceros under Wine.
#
# Configures a Wine prefix with:
#  1. AppDefaults registry overrides (DXVK for Rhino viewports, builtin DComp for WebView2).
#  2. Critical DLL overrides (vcomp140=builtin for lock-free dynamic loop scheduling).
#  3. High-performance DXVK configuration (parallel pipeline compilation, zero queue latency).
#  4. Windows font registry aliases.
#  5. RhinoGreet startup flow patching for splash & template screen stability.
#  6. Desktop integration (.desktop launcher and icons).
#
# Usage:
#   ./deploy-rhino.sh [OPTIONS]
#
# Options:
#   --prefix <PATH>     Target Wine prefix (default: $RHINO_PREFIX or ~/.wine-rhino)
#   --wine <PATH>       Path to patched Wine binary (default: $WINE or system wine)
#   --skip-desktop      Skip installing desktop menu launcher and icons
#   -h, --help          Show this help message
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
TARGET_PREFIX="${RHINO_PREFIX:-${WINEPREFIX:-}}"
if [ -z "$TARGET_PREFIX" ]; then
    if [ -d "$HOME/.wine-rhino" ]; then
        TARGET_PREFIX="$HOME/.wine-rhino"
    elif [ -d "/home/jaberm/src/rhino-lab/prefix-rhino9" ]; then
        TARGET_PREFIX="/home/jaberm/src/rhino-lab/prefix-rhino9"
    else
        TARGET_PREFIX="$HOME/.wine-rhino"
    fi
fi

WINE_BIN="${WINE:-}"
if [ -z "$WINE_BIN" ]; then
    if [ -x "$HOME/.local/share/wine-rhino/bin/wine" ]; then
        WINE_BIN="$HOME/.local/share/wine-rhino/bin/wine"
    elif [ -x "/opt/wine-rhino/bin/wine" ]; then
        WINE_BIN="/opt/wine-rhino/bin/wine"
    elif [ -x "$REPO_DIR/build-wine/wine" ]; then
        WINE_BIN="$REPO_DIR/build-wine/wine"
    elif [ -x "/home/jaberm/src/rhino-lab/build-wine/wine" ]; then
        WINE_BIN="/home/jaberm/src/rhino-lab/build-wine/wine"
    elif command -v wine >/dev/null 2>&1; then
        WINE_BIN="$(command -v wine)"
    else
        echo "Error: Wine binary not found. Specify --wine /path/to/wine or ensure wine is in PATH." >&2
        exit 1
    fi
fi

SKIP_DESKTOP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            TARGET_PREFIX="$2"
            shift 2
            ;;
        --wine)
            WINE_BIN="$2"
            shift 2
            ;;
        --skip-desktop)
            SKIP_DESKTOP=1
            shift
            ;;
        -h|--help)
            sed -ne '/^#/!q;s/^# //;2,$p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo " Rhino Prefix Setup"
echo "=========================================================="
echo "Prefix: $TARGET_PREFIX"
echo "Wine  : $WINE_BIN"
echo "Script Dir    : $SCRIPT_DIR"
echo "=========================================================="

export WINEPREFIX="$TARGET_PREFIX"
export WINEARCH="win64"
export WINEDEBUG="-all"

WINESERVER_BIN="$(dirname "$WINE_BIN")/wineserver"
if [ ! -x "$WINESERVER_BIN" ]; then
    WINESERVER_BIN="$(dirname "$WINE_BIN")/server/wineserver"
fi
[ -x "$WINESERVER_BIN" ] || WINESERVER_BIN="$(command -v wineserver 2>/dev/null || echo "wineserver")"

# 1. Initialize Prefix if needed
if [ ! -d "$TARGET_PREFIX/drive_c" ]; then
    echo "[1/5] Initializing fresh 64-bit Wine prefix..."
    "$WINE_BIN" wineboot -u
    timeout 5 "$WINESERVER_BIN" -w 2>/dev/null || true
else
    echo "[1/5] Existing prefix detected at $TARGET_PREFIX."
fi

# 2. Registry Overrides & AppDefaults
echo "[2/5] Applying AppDefaults & DLL overrides..."
REG_FILE="$(mktemp /tmp/rhino-deploy-XXXXXX.reg)"
cat << 'EOF' > "$REG_FILE"
Windows Registry Editor Version 5.00

; Global overrides
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"vcomp140"="builtin"
"d3dcompiler_47"="native,builtin"

; Rhino executable: native DXVK for viewport acceleration
[HKEY_CURRENT_USER\Software\Wine\AppDefaults\Rhino.exe\DllOverrides]
"d3d11"="native"
"dxgi"="native"
"d3d10core"="native"
"d3d9"="native"
"d3dcompiler_47"="native,builtin"
"vcomp140"="builtin"

; Microsoft Edge WebView2: builtin Wine DComp for visual tree hosting
[HKEY_CURRENT_USER\Software\Wine\AppDefaults\msedgewebview2.exe\DllOverrides]
"d3d11"="builtin"
"dxgi"="builtin"
"d3d10core"="builtin"
"dcomp"="builtin"

; Force X11/XWayland driver for mature 32bpp alpha blending and XDamage presentation
[HKEY_CURRENT_USER\Software\Wine\Drivers]
"Graphics"="x11"

; Windows version reporting
[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion]
"CurrentBuild"="19045"
"CurrentBuildNumber"="19045"
"ProductName"="Windows 10 Pro"
EOF

"$WINE_BIN" regedit /S "$REG_FILE"
rm -f "$REG_FILE"

# Import font registry if available
if [ -f "$SCRIPT_DIR/windows-fonts.reg" ]; then
    echo "[2/5] Applying Windows font substitution entries..."
    "$WINE_BIN" regedit /S "$SCRIPT_DIR/windows-fonts.reg"
fi
timeout 5 "$WINESERVER_BIN" -w 2>/dev/null || true

# 3. DXVK Configuration
echo "[3/5] Deploying DXVK configuration..."
RHINO_SYS_DIR="$TARGET_PREFIX/drive_c/Program Files/Rhino 9 WIP/System"
if [ -d "$RHINO_SYS_DIR" ]; then
    cp -v "$SCRIPT_DIR/dxvk-rhino.conf" "$RHINO_SYS_DIR/dxvk.conf"
    # Deploy Rhino-bundled annotation fonts to Windows Fonts directory
    FONTS_DIR="$TARGET_PREFIX/drive_c/windows/Fonts"
    if [ -d "$FONTS_DIR" ]; then
        for font in "$RHINO_SYS_DIR"/*.ttf; do
            [ -f "$font" ] && cp -u -v "$font" "$FONTS_DIR/" 2>/dev/null || true
        done
    fi
    if [ -f "$RHINO_SYS_DIR/RhinoGreet.dll" ] && [ ! -f "$RHINO_SYS_DIR/netcore/RhinoGreet.dll" ]; then
        mkdir -p "$RHINO_SYS_DIR/netcore"
        cp -v "$RHINO_SYS_DIR/RhinoGreet.dll" "$RHINO_SYS_DIR/netcore/RhinoGreet.dll"
    fi
fi
USER_DXVK_DIR="$TARGET_PREFIX/drive_c/users/$USER/AppData/Local/dxvk"
mkdir -p "$USER_DXVK_DIR"
cp -v "$SCRIPT_DIR/dxvk-rhino.conf" "$USER_DXVK_DIR/dxvk.conf" 2>/dev/null || true

# 4. Launcher Installation
echo "[4/5] Installing launcher script..."
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
cp -v "$SCRIPT_DIR/rhino-9" "$BIN_DIR/rhino-9"
chmod +x "$BIN_DIR/rhino-9"

# 5. Desktop Integration
if [ "$SKIP_DESKTOP" -eq 0 ]; then
    echo "[5/5] Installing Desktop launcher and icons..."
    ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
    APPS_DIR="$HOME/.local/share/applications"
    mkdir -p "$ICON_DIR" "$APPS_DIR"

    if [ -f "$SCRIPT_DIR/rhino9-256.png" ]; then
        cp -v "$SCRIPT_DIR/rhino9-256.png" "$ICON_DIR/rhino9.png"
    fi

    cat << EOF > "$APPS_DIR/rhino-9.desktop"
[Desktop Entry]
Name=Rhinoceros
GenericName=3D CAD Modeler
Comment=Design, model, and fabricate with Rhinoceros on Linux
Exec=$BIN_DIR/rhino-9 %F
Icon=rhino9
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=application/x-3dm;
StartupWMClass=Rhino.exe
StartupNotify=true
EOF
    chmod +x "$APPS_DIR/rhino-9.desktop"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPS_DIR" 2>/dev/null || true
    fi
    echo "      Desktop integration complete."
else
    echo "[5/5] Desktop integration skipped."
fi

echo "=========================================================="
echo " Prefix setup complete. Launch with: rhino-9"
echo "=========================================================="
