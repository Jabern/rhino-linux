#!/usr/bin/env bash
# deploy-rhino.sh — Automated prefix deployment & configuration for Rhinoceros under Wine.
#
# Configures a Wine prefix with:
#  1. Native DXVK DLLs (d3d11, dxgi, d3d9, d3d10core) deployed into system32.
#  2. AppDefaults registry overrides (DXVK for Rhino viewports, builtin DComp for WebView2).
#  3. Critical DLL overrides (vcomp140=builtin for lock-free dynamic loop scheduling).
#  4. High-performance DXVK configuration (parallel pipeline compilation, low latency).
#  5. Windows font registry aliases and Rhino-bundled annotation fonts.
#  6. Shared asset deployment (~/.local/share/rhino-linux).
#  7. Persistent configuration storage (~/.config/rhino-linux/config).
#  8. Desktop integration (.desktop launcher and icons).
#
# Usage:
#   ./deploy-rhino.sh [OPTIONS]
#
# Options:
#   --prefix <PATH>     Target Wine prefix (default: $RHINO_PREFIX or ~/.wine-rhino)
#   --wine <PATH>       Path to patched Wine binary (default: $WINE or system wine)
#   --dxvk-dir <PATH>   Path to custom DXVK 64-bit DLL directory
#   --skip-desktop      Skip installing desktop menu launcher and icons
#   -h, --help          Show this help message
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
TARGET_PREFIX="${RHINO_PREFIX:-${WINEPREFIX:-}}"
if [ -z "$TARGET_PREFIX" ]; then
    TARGET_PREFIX="$HOME/.wine-rhino"
fi

WINE_BIN="${WINE:-}"
if [ -z "$WINE_BIN" ]; then
    if [ -x "$HOME/.local/share/wine-rhino/bin/wine" ]; then
        WINE_BIN="$HOME/.local/share/wine-rhino/bin/wine"
    elif [ -x "/opt/wine-rhino/bin/wine" ]; then
        WINE_BIN="/opt/wine-rhino/bin/wine"
    elif [ -x "$REPO_DIR/build-wine/wine" ]; then
        WINE_BIN="$REPO_DIR/build-wine/wine"
    elif command -v wine >/dev/null 2>&1; then
        WINE_BIN="$(command -v wine)"
    else
        echo "Error: Wine binary not found. Specify --wine /path/to/wine or ensure wine is in PATH." >&2
        exit 1
    fi
fi

CUSTOM_DXVK_DIR=""
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
        --dxvk-dir)
            CUSTOM_DXVK_DIR="$2"
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
echo "Script: $SCRIPT_DIR"
echo "=========================================================="

export WINEPREFIX="$TARGET_PREFIX"
export WINEARCH="win64"
export WINEDEBUG="-all"

WINESERVER_BIN="$(dirname "$WINE_BIN")/wineserver"
if [ ! -x "$WINESERVER_BIN" ]; then
    WINESERVER_BIN="$(dirname "$WINE_BIN")/server/wineserver"
fi
if [ ! -x "$WINESERVER_BIN" ]; then
    WINESERVER_BIN="$(dirname "$WINE_BIN")/../server/wineserver"
fi
[ -x "$WINESERVER_BIN" ] || WINESERVER_BIN="$(command -v wineserver 2>/dev/null || echo "wineserver")"

# 1. Initialize Prefix if needed
if [ ! -d "$TARGET_PREFIX/drive_c" ]; then
    echo "[1/6] Initializing fresh 64-bit Wine prefix..."
    "$WINE_BIN" wineboot -u
    timeout 10 "$WINESERVER_BIN" -w 2>/dev/null || true
else
    echo "[1/6] Existing prefix detected at $TARGET_PREFIX."
fi

# 2. Deploy DXVK DLLs to system32
echo "[2/6] Deploying DXVK 64-bit runtime libraries..."
SYSTEM32_DIR="$TARGET_PREFIX/drive_c/windows/system32"
mkdir -p "$SYSTEM32_DIR"

is_dxvk_dll() {
    local dll="$1"
    [ -f "$dll" ] && [ "$(stat -c%s "$dll" 2>/dev/null || stat -f%z "$dll" 2>/dev/null || echo 0)" -gt 500000 ]
}

deploy_dxvk_from_dir() {
    local src_dir="$1"
    if [ -f "$src_dir/d3d11.dll" ]; then
        echo "      Copying DXVK libraries from $src_dir..."
        for dll in d3d11.dll dxgi.dll d3d9.dll d3d10core.dll; do
            [ -f "$src_dir/$dll" ] && cp -f "$src_dir/$dll" "$SYSTEM32_DIR/$dll"
        done
        return 0
    fi
    return 1
}

DXVK_DEPLOYED=0

if [ -n "$CUSTOM_DXVK_DIR" ] && deploy_dxvk_from_dir "$CUSTOM_DXVK_DIR"; then
    DXVK_DEPLOYED=1
fi

if [ "$DXVK_DEPLOYED" -eq 0 ]; then
    for candidate in \
        "/usr/lib/dxvk/x64" \
        "/usr/share/dxvk/x64" \
        "/usr/lib64/dxvk" \
        "/usr/lib/wine/dxvk/x86_64-windows" \
        "/usr/share/dxvk/x86_64"; do
        if deploy_dxvk_from_dir "$candidate"; then
            DXVK_DEPLOYED=1
            break
        fi
    done
fi

if [ "$DXVK_DEPLOYED" -eq 0 ] && command -v setup_dxvk.sh >/dev/null 2>&1; then
    echo "      Running system setup_dxvk.sh install..."
    WINEPREFIX="$TARGET_PREFIX" setup_dxvk.sh install 2>/dev/null || true
    if is_dxvk_dll "$SYSTEM32_DIR/d3d11.dll"; then
        DXVK_DEPLOYED=1
    fi
fi

if [ "$DXVK_DEPLOYED" -eq 0 ] && command -v setup_dxvk >/dev/null 2>&1; then
    echo "      Running system setup_dxvk install..."
    WINEPREFIX="$TARGET_PREFIX" setup_dxvk install 2>/dev/null || true
    if is_dxvk_dll "$SYSTEM32_DIR/d3d11.dll"; then
        DXVK_DEPLOYED=1
    fi
fi

if [ "$DXVK_DEPLOYED" -eq 0 ] && ! is_dxvk_dll "$SYSTEM32_DIR/d3d11.dll"; then
    echo "      Fetching pinned DXVK 2.4 release archive..."
    DXVK_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rhino-linux"
    DXVK_TARBALL="$DXVK_CACHE_DIR/dxvk-2.4.tar.gz"
    DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v2.4/dxvk-2.4.tar.gz"
    DXVK_SHA256="784eb023fb8da8868aa562c30ef5562989211fc9fda6bc5155d95e28049fccc7"

    mkdir -p "$DXVK_CACHE_DIR"
    if [ ! -f "$DXVK_TARBALL" ] || ! echo "$DXVK_SHA256  $DXVK_TARBALL" | sha256sum -c --status 2>/dev/null; then
        temp_dl="$DXVK_TARBALL.part.$$"
        if command -v curl >/dev/null 2>&1; then
            curl -fL -o "$temp_dl" "$DXVK_URL"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$temp_dl" "$DXVK_URL"
        fi
        if echo "$DXVK_SHA256  $temp_dl" | sha256sum -c --status 2>/dev/null; then
            mv -f "$temp_dl" "$DXVK_TARBALL"
        else
            echo "Warning: DXVK download verification failed." >&2
            rm -f "$temp_dl"
        fi
    fi

    if [ -f "$DXVK_TARBALL" ]; then
        temp_extract="$(mktemp -d)"
        tar -xzf "$DXVK_TARBALL" -C "$temp_extract"
        if deploy_dxvk_from_dir "$temp_extract/dxvk-2.4/x64"; then
            DXVK_DEPLOYED=1
        fi
        rm -rf "$temp_extract"
    fi
fi

if is_dxvk_dll "$SYSTEM32_DIR/d3d11.dll"; then
    echo "      [PASS] Native DXVK libraries verified in $SYSTEM32_DIR"
else
    echo "      [WARN] Native DXVK libraries could not be automatically deployed."
    echo "             Rhino will fall back to WineD3D unless DXVK DLLs are installed manually."
fi

# 3. Registry Overrides & AppDefaults
echo "[3/6] Applying AppDefaults & DLL overrides..."
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
    echo "      Applying Windows font substitution entries..."
    "$WINE_BIN" regedit /S "$SCRIPT_DIR/windows-fonts.reg"
fi
timeout 5 "$WINESERVER_BIN" -w 2>/dev/null || true

# 4. DXVK Configuration & Fonts
echo "[4/6] Deploying DXVK configuration & fonts..."
RHINO_SYS_DIR="$TARGET_PREFIX/drive_c/Program Files/Rhino 9 WIP/System"
if [ -d "$RHINO_SYS_DIR" ]; then
    cp -v "$SCRIPT_DIR/dxvk-rhino.conf" "$RHINO_SYS_DIR/dxvk.conf" 2>/dev/null || true
    FONTS_DIR="$TARGET_PREFIX/drive_c/windows/Fonts"
    if [ -d "$FONTS_DIR" ]; then
        for font in "$RHINO_SYS_DIR"/*.ttf; do
            [ -f "$font" ] && cp -u -v "$font" "$FONTS_DIR/" 2>/dev/null || true
        done
    fi
    if [ -f "$RHINO_SYS_DIR/RhinoGreet.dll" ] && [ ! -f "$RHINO_SYS_DIR/netcore/RhinoGreet.dll" ]; then
        mkdir -p "$RHINO_SYS_DIR/netcore"
        cp -v "$RHINO_SYS_DIR/RhinoGreet.dll" "$RHINO_SYS_DIR/netcore/RhinoGreet.dll" 2>/dev/null || true
    fi
fi
USER_DXVK_DIR="$TARGET_PREFIX/drive_c/users/$USER/AppData/Local/dxvk"
mkdir -p "$USER_DXVK_DIR"
cp -v "$SCRIPT_DIR/dxvk-rhino.conf" "$USER_DXVK_DIR/dxvk.conf" 2>/dev/null || true

# 5. Shared Companion Assets & Config Persistence
echo "[5/6] Deploying companion assets & saving launcher configuration..."
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rhino-linux"
mkdir -p "$DATA_DIR"
for asset in "msedgewebview2-stub.exe" "dxvk-rhino.conf" "windows-fonts.reg" "rhino9-256.png" "rhino9-icon.png"; do
    if [ -f "$SCRIPT_DIR/$asset" ]; then
        cp -f "$SCRIPT_DIR/$asset" "$DATA_DIR/$asset"
    fi
done

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rhino-linux"
mkdir -p "$CONFIG_DIR"
cat << EOF > "$CONFIG_DIR/config"
# Rhino Linux Configuration (Generated by deploy-rhino.sh)
RHINO_PREFIX="$TARGET_PREFIX"
RHINO_WINE="$WINE_BIN"
RHINO_WINESERVER="$WINESERVER_BIN"
EOF

# 6. Launcher Installation & Desktop Integration
echo "[6/6] Installing launcher script & desktop entries..."
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
cp -f "$SCRIPT_DIR/rhino-9" "$BIN_DIR/rhino-9"
chmod +x "$BIN_DIR/rhino-9"

if [ "$SKIP_DESKTOP" -eq 0 ]; then
    ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
    APPS_DIR="$HOME/.local/share/applications"
    mkdir -p "$ICON_DIR" "$APPS_DIR"

    if [ -f "$SCRIPT_DIR/rhino9-256.png" ]; then
        cp -f "$SCRIPT_DIR/rhino9-256.png" "$ICON_DIR/rhino9.png"
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
    echo "      Desktop integration skipped."
fi

echo "=========================================================="
echo " Prefix setup complete. Launch with: rhino-9"
echo "=========================================================="
