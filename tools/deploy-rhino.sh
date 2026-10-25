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
    # Inside the Flatpak the prefix lives in the app's private data directory.
    if [ -n "${FLATPAK_ID:-}" ]; then TARGET_PREFIX="$XDG_DATA_HOME/prefix"; else TARGET_PREFIX="$HOME/.wine-rhino"; fi
fi

WINE_BIN="${WINE:-}"
if [ -z "$WINE_BIN" ]; then
    if [ -x "${XDG_DATA_HOME:-$HOME/.local/share}/wine-rhino/bin/wine" ]; then
        WINE_BIN="${XDG_DATA_HOME:-$HOME/.local/share}/wine-rhino/bin/wine"
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
# The Flatpak exports its own launcher and menu entries.
[ -n "${FLATPAK_ID:-}" ] && SKIP_DESKTOP=1

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
    # The Rhino installer needs Wine Mono (.NET Framework) and uses the IE control
    # (Wine Gecko). Wine installs both silently from its cache instead of asking
    # the user, so stage the versions this Wine release expects (11.18).
    WINE_ADDON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wine"
    mkdir -p "$WINE_ADDON_CACHE"
    while read -r addon sum; do
        file="$WINE_ADDON_CACHE/$(basename "$addon")"
        if [ -f "$file" ] && echo "$sum  $file" | sha256sum -c --status 2>/dev/null; then continue; fi
        echo "      Downloading $(basename "$addon")..."
        if curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors -o "$file.part" "https://dl.winehq.org/wine/$addon" &&
           echo "$sum  $file.part" | sha256sum -c --status 2>/dev/null; then
            mv -f "$file.part" "$file"
        else
            rm -f "$file.part"
            echo "      [WARN] Could not download $(basename "$addon"); Wine will ask to install it."
        fi
    done <<'ADDONS'
wine-mono/11.3.0/wine-mono-11.3.0-x86.msi df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3
wine-gecko/2.47.4/wine-gecko-2.47.4-x86.msi 26cecc47706b091908f7f814bddb074c61beb8063318e9efc5a7f789857793d6
wine-gecko/2.47.4/wine-gecko-2.47.4-x86_64.msi e590b7d988a32d6aa4cf1d8aa3aa3d33766fdd4cf4c89c2dcc2095ecb28d066f
ADDONS
    "$WINE_BIN" wineboot -u
    timeout 10 "$WINESERVER_BIN" -w 2>/dev/null || true
else
    echo "[1/6] Existing prefix detected at $TARGET_PREFIX."
fi

# wineboot only installs the 32-bit Gecko, but Rhino is 64-bit: its HTML views
# (RhinoScript's Rhino.HtmlBox) need the 64-bit one. Also fixes older prefixes.
GECKO64_MSI="${XDG_CACHE_HOME:-$HOME/.cache}/wine/wine-gecko-2.47.4-x86_64.msi"
if [ ! -d "$TARGET_PREFIX/drive_c/windows/system32/gecko/2.47.4" ]; then
    if [ ! -f "$GECKO64_MSI" ]; then
        mkdir -p "$(dirname "$GECKO64_MSI")"
        curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors -o "$GECKO64_MSI.part" \
            "https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86_64.msi" &&
            echo "e590b7d988a32d6aa4cf1d8aa3aa3d33766fdd4cf4c89c2dcc2095ecb28d066f  $GECKO64_MSI.part" | sha256sum -c --status 2>/dev/null &&
            mv -f "$GECKO64_MSI.part" "$GECKO64_MSI"
        rm -f "$GECKO64_MSI.part"
    fi
    if [ -f "$GECKO64_MSI" ] && "$WINE_BIN" msiexec /i "$GECKO64_MSI" /qn; then
        echo "      [PASS] 64-bit Wine Gecko installed (HTML dialogs)"
    else
        echo "      [WARN] Could not install the 64-bit Wine Gecko; Rhino.HtmlBox will not work"
    fi
fi

# 2. Deploy DXVK DLLs to system32
echo "[2/6] Deploying DXVK 64-bit runtime libraries..."
SYSTEM32_DIR="$TARGET_PREFIX/drive_c/windows/system32"
mkdir -p "$SYSTEM32_DIR"

# Identify DXVK by content, not size: Wine's own builtin d3d11.dll is several MB
# and carries the "Wine builtin DLL" marker, DXVK's references its DXVK_* env vars.
is_dxvk_dll() {
    local dll="$1"
    [ -f "$dll" ] && ! grep -qa "Wine builtin DLL" "$dll" && grep -qa "DXVK_" "$dll"
}

deploy_dxvk_from_dir() {
    local src_dir="$1"
    if is_dxvk_dll "$src_dir/d3d11.dll"; then
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

verify_sha256() {
    local expected="$1"
    local file="$2"
    if command -v sha256sum >/dev/null 2>&1; then
        echo "$expected  $file" | sha256sum -c --status 2>/dev/null
    elif command -v shasum >/dev/null 2>&1; then
        echo "$expected  $file" | shasum -a 256 -c --status 2>/dev/null
    else
        echo "Error: sha256sum or shasum is required to verify downloads." >&2
        return 1
    fi
}

if [ "$DXVK_DEPLOYED" -eq 0 ] && ! is_dxvk_dll "$SYSTEM32_DIR/d3d11.dll"; then
    echo "      Fetching pinned DXVK 2.4 release archive..."
    DXVK_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rhino-linux"
    DXVK_TARBALL="$DXVK_CACHE_DIR/dxvk-2.4.tar.gz"
    DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v2.4/dxvk-2.4.tar.gz"
    DXVK_SHA256="784eb023fb8da8868aa562c30ef5562989211fc9fda6bc5155d95e28049fccc7"

    mkdir -p "$DXVK_CACHE_DIR"
    if [ ! -f "$DXVK_TARBALL" ] || ! verify_sha256 "$DXVK_SHA256" "$DXVK_TARBALL"; then
        temp_dl="$DXVK_TARBALL.part.$$"
        if command -v curl >/dev/null 2>&1; then
            curl -fL --retry 3 --retry-delay 5 --retry-all-errors -o "$temp_dl" "$DXVK_URL"
        elif command -v wget >/dev/null 2>&1; then
            wget --tries=4 --waitretry=5 -O "$temp_dl" "$DXVK_URL"
        fi
        if verify_sha256 "$DXVK_SHA256" "$temp_dl"; then
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
; Wine's menu builder turns Windows shortcuts into desktop entries that call the
; system's wine, not ours (and outside the Flatpak); rhino-9 has its own entries.
"winemenubuilder.exe"=""

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

# WebView2's installer registers Edge Update as an auto-start service. It never
# exits, so it keeps wineserver alive after Rhino closes; WebView2 runs without it.
for svc in edgeupdate edgeupdatem; do
    if grep -qi "^\[System\\\\\\\\ControlSet001\\\\\\\\Services\\\\\\\\$svc\]" "$TARGET_PREFIX/system.reg" 2>/dev/null; then
        echo "      Disabling the Microsoft Edge Update service ($svc)..."
        "$WINE_BIN" reg add "HKLM\\System\\CurrentControlSet\\Services\\$svc" /v Start /t REG_DWORD /d 4 /f >/dev/null 2>&1 || true
    fi
done
timeout 5 "$WINESERVER_BIN" -w 2>/dev/null || true

# 4. DXVK Configuration & Fonts
echo "[4/6] Deploying DXVK configuration & fonts..."
FONTS_DIR="$TARGET_PREFIX/drive_c/windows/Fonts"
mkdir -p "$FONTS_DIR"

# Resolve mandatory Arial core fonts required by WPF/.NET 10 typography fallback
if [ ! -f "$FONTS_DIR/arial.ttf" ]; then
    echo "      Resolving mandatory Arial core fonts for WPF/.NET..."

    # 1. Search local system font directories and Windows partitions
    for candidate_dir in \
        "/usr/share/fonts/truetype/msttcorefonts" \
        "/usr/share/fonts/msttcorefonts" \
        "/usr/share/fonts/TTF" \
        "/usr/share/fonts/truetype" \
        "/usr/share/fonts" \
        "/usr/local/share/fonts" \
        "$HOME/.local/share/fonts" \
        "$HOME/.fonts" \
        /run/media/*/*/Windows/Fonts \
        /run/media/*/*/windows/fonts \
        /mnt/*/Windows/Fonts \
        /mnt/*/windows/fonts \
        /media/*/*/Windows/Fonts \
        "$HOME"/.wine/drive_c/windows/Fonts \
        "$HOME"/.local/share/wineprefixes/*/drive_c/windows/Fonts; do
        if [ -d "$candidate_dir" ]; then
            found_fonts=()
            while IFS= read -r -d '' font_match; do
                found_fonts+=("$font_match")
            done < <(find "$candidate_dir" -maxdepth 2 -iname "arial*.ttf" -print0 2>/dev/null)

            if [ "${#found_fonts[@]}" -gt 0 ]; then
                for font in "${found_fonts[@]}"; do
                    target_name="$(basename "$font" | tr '[:upper:]' '[:lower:]')"
                    cp -f "$font" "$FONTS_DIR/$target_name"
                done
                if [ -f "$FONTS_DIR/arial.ttf" ]; then
                    echo "      Copied Arial fonts from $candidate_dir"
                    break
                fi
            fi
        fi
    done

    # 2. If not found locally, fetch Microsoft corefonts package (arial32.exe)
    if [ ! -f "$FONTS_DIR/arial.ttf" ]; then
        echo "      Fetching Microsoft corefonts package (arial32.exe)..."
        FONT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rhino-linux/fonts"
        mkdir -p "$FONT_CACHE_DIR"
        ARIAL_EXE="$FONT_CACHE_DIR/arial32.exe"
        ARIAL_SHA256="85297a4d146e9c87ac6f74822734bdee5f4b2a722d7eaa584b7f2cbf76f478f6"

        for cached in \
            "$FONT_CACHE_DIR/arial32.exe" \
            "${XDG_CACHE_HOME:-$HOME/.cache}/winetricks/corefonts/arial32.exe" \
            "$HOME/.cache/winetricks/corefonts/arial32.exe"; do
            if [ -f "$cached" ] && verify_sha256 "$ARIAL_SHA256" "$cached"; then
                [ "$cached" -ef "$ARIAL_EXE" ] || cp -f "$cached" "$ARIAL_EXE"
                break
            fi
        done

        if [ ! -f "$ARIAL_EXE" ] || ! verify_sha256 "$ARIAL_SHA256" "$ARIAL_EXE"; then
            temp_dl="$ARIAL_EXE.part.$$"
            for url in \
                "https://github.com/pushcx/corefonts/raw/master/arial32.exe" \
                "https://downloads.sourceforge.net/corefonts/arial32.exe"; do
                if command -v curl >/dev/null 2>&1; then
                    curl -fLs --retry 3 --retry-delay 5 --retry-all-errors -o "$temp_dl" "$url" || true
                elif command -v wget >/dev/null 2>&1; then
                    wget -q --tries=4 --waitretry=5 -O "$temp_dl" "$url" || true
                fi
                if [ -f "$temp_dl" ] && verify_sha256 "$ARIAL_SHA256" "$temp_dl"; then
                    mv -f "$temp_dl" "$ARIAL_EXE"
                    break
                fi
                rm -f "$temp_dl"
            done
        fi

        # 3. Extract with cabextract, bsdtar, or 7z
        if [ -f "$ARIAL_EXE" ] && verify_sha256 "$ARIAL_SHA256" "$ARIAL_EXE"; then
            temp_extract="$(mktemp -d)"
            if command -v cabextract >/dev/null 2>&1; then
                cabextract -q -d "$temp_extract" "$ARIAL_EXE" 2>/dev/null || true
            elif command -v bsdtar >/dev/null 2>&1; then
                bsdtar -xf "$ARIAL_EXE" -C "$temp_extract" 2>/dev/null || true
            elif command -v 7z >/dev/null 2>&1; then
                7z x -y -o"$temp_extract" "$ARIAL_EXE" >/dev/null 2>&1 || true
            elif [ -x "$WINE_BIN" ]; then
                # Self-extract directly using Wine if no native unpacker is installed
                "$WINE_BIN" "$ARIAL_EXE" /q /c "/t:Z:$temp_extract" >/dev/null 2>&1 || true
            fi

            for font in "$temp_extract"/*.[tT][tT][fF]; do
                if [ -f "$font" ]; then
                    target_name="$(basename "$font" | tr '[:upper:]' '[:lower:]')"
                    cp -f "$font" "$FONTS_DIR/$target_name"
                fi
            done
            rm -rf "$temp_extract"
        fi
    fi
fi

if [ -f "$FONTS_DIR/arial.ttf" ]; then
    echo "      [PASS] Mandatory Arial font verified in $FONTS_DIR"
else
    echo "      [WARN] Arial font not detected. WPF .NET 10 UI may fail fast."
fi

# Wine registers its own core fonts by the absolute path of the Wine build that ran
# first. If that build moves or is deleted, DirectWrite cannot find Tahoma, and
# WebView2 (Rhino's sign-in) crashes in an endless system-font loop. Keep copies in
# the prefix and register them by file name, as Windows does.
WINE_REAL="$(readlink -f "$(command -v "$WINE_BIN" 2>/dev/null || echo "$WINE_BIN")")"
WINE_FONT_SRC=""
for dir in "$(dirname "$WINE_REAL")/../share/wine/fonts" "$(dirname "$WINE_REAL")/fonts"; do
    if [ -f "$dir/tahoma.ttf" ]; then WINE_FONT_SRC="$dir"; break; fi
done
if [ -n "$WINE_FONT_SRC" ]; then
    CORE_FONTS_REG="$(mktemp "${TMPDIR:-/tmp}/rhino-fonts-XXXXXX.reg")"
    printf 'Windows Registry Editor Version 5.00\n' > "$CORE_FONTS_REG"
    for key in 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
               'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Fonts' \
               'HKEY_CURRENT_USER\Software\Wine\Fonts\External Fonts'; do
        printf '\n[%s]\n' "$key" >> "$CORE_FONTS_REG"
        while IFS='|' read -r name file; do
            cp -f "$WINE_FONT_SRC/$file" "$FONTS_DIR/$file"
            case "$key" in
                *External*) printf '"%s"=-\n' "$name" >> "$CORE_FONTS_REG" ;;
                *)          printf '"%s"="%s"\n' "$name" "$file" >> "$CORE_FONTS_REG" ;;
            esac
        done <<'EOF'
Tahoma (TrueType)|tahoma.ttf
Tahoma Bold (TrueType)|tahomabd.ttf
Marlett (TrueType)|marlett.ttf
Symbol (TrueType)|symbol.ttf
Webdings (TrueType)|webdings.ttf
Wingdings (TrueType)|wingding.ttf
EOF
    done
    "$WINE_BIN" regedit /S "$CORE_FONTS_REG"
    rm -f "$CORE_FONTS_REG"
    echo "      [PASS] Wine's core fonts registered from the prefix (Tahoma for web views)"
else
    echo "      [WARN] Wine's own fonts not found next to $WINE_BIN; web views may not start"
fi

# Rhino's folder under Program Files: the newest release first, then the WIP build.
find_rhino_dir() {
    local name
    for name in "Rhino 9" "Rhino 9 WIP" "Rhino 8"; do
        if [ -f "$1/drive_c/Program Files/$name/System/Rhino.exe" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    done
    return 1
}
RHINO_SYS_DIR=""   # stays empty until the Rhino installer has run
if RHINO_NAME="$(find_rhino_dir "$TARGET_PREFIX")"; then
    RHINO_SYS_DIR="$TARGET_PREFIX/drive_c/Program Files/$RHINO_NAME/System"
    cp -v "$SCRIPT_DIR/dxvk-rhino.conf" "$RHINO_SYS_DIR/dxvk.conf" 2>/dev/null || true
    for font in "$RHINO_SYS_DIR"/*.ttf; do
        [ -f "$font" ] && cp -u -v "$font" "$FONTS_DIR/" 2>/dev/null || true
    done
    if [ -f "$RHINO_SYS_DIR/RhinoGreet.dll" ] && [ ! -f "$RHINO_SYS_DIR/netcore/RhinoGreet.dll" ]; then
        mkdir -p "$RHINO_SYS_DIR/netcore"
        cp -v "$RHINO_SYS_DIR/RhinoGreet.dll" "$RHINO_SYS_DIR/netcore/RhinoGreet.dll" 2>/dev/null || true
    fi
fi

# The Rhino installer puts a Windows shortcut (.lnk) on the Desktop. Wine maps that
# folder to the real Desktop, where Linux cannot open it; our menu entries replace it.
DESKTOP_DIR="$(readlink -f "$TARGET_PREFIX/drive_c/users/$(id -un)/Desktop" 2>/dev/null || true)"
if [ -n "$DESKTOP_DIR" ] && [ -d "$DESKTOP_DIR" ]; then
    for lnk in "$DESKTOP_DIR"/Rhino*.lnk; do
        [ -f "$lnk" ] || continue
        rm -f "$lnk"
        echo "      Removed the Windows shortcut $(basename "$lnk") from the Desktop"
    done
fi

# Rhino compiles display-mode shaders at runtime (Artistic, Monochrome, ...); Wine's
# builtin d3dcompiler_47 cannot compile them and those viewports stay black. Use
# Microsoft's compiler from the WebView2 runtime that the Rhino installer put in
# the prefix (newest 64-bit copy).
# PE machine type 0x8664 (x86-64), read from the header: offset of "PE\0\0" at 0x3c.
pe_is_x86_64() {
    local pe
    pe="$(od -An -tu4 -j 60 -N 4 "$1" 2>/dev/null | tr -d ' ')"
    [ -n "$pe" ] && [ "$(od -An -tx2 -j $((pe + 4)) -N 2 "$1" 2>/dev/null | tr -d ' ')" = "8664" ]
}
SYSTEM32_COMPILER="$TARGET_PREFIX/drive_c/windows/system32/d3dcompiler_47.dll"
NATIVE_COMPILER=""
while IFS= read -r candidate; do
    grep -qa "Wine builtin DLL" "$candidate" && continue
    pe_is_x86_64 "$candidate" || continue
    NATIVE_COMPILER="$candidate"
done < <(ls -d "$TARGET_PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application"/*/d3dcompiler_47.dll 2>/dev/null | sort -V)
if [ -n "$NATIVE_COMPILER" ]; then
    cp -f "$NATIVE_COMPILER" "$SYSTEM32_COMPILER"
    echo "      [PASS] Native d3dcompiler_47 installed from the WebView2 runtime"
elif [ -n "$RHINO_SYS_DIR" ] && [ -d "$RHINO_SYS_DIR" ] && grep -qa "Wine builtin DLL" "$SYSTEM32_COMPILER" 2>/dev/null; then
    echo "      [WARN] No native d3dcompiler_47 found; Artistic/Monochrome display modes will render black."
fi
WINE_USER_NAME="${USER:-}"
if [ ! -d "$TARGET_PREFIX/drive_c/users/$WINE_USER_NAME" ]; then
    WINE_USER_NAME="$(ls "$TARGET_PREFIX/drive_c/users" 2>/dev/null | grep -v -E "^(Public|Default)$" | head -n1 || echo "${USER:-user}")"
fi
USER_DXVK_DIR="$TARGET_PREFIX/drive_c/users/$WINE_USER_NAME/AppData/Local/dxvk"
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
if [ "$SKIP_DESKTOP" -eq 0 ]; then
    mkdir -p "$BIN_DIR"
    cp -f "$SCRIPT_DIR/rhino-9" "$BIN_DIR/rhino-9"
    chmod +x "$BIN_DIR/rhino-9"
fi

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

    # The setup and maintenance app (needs Python with GTK 4 and libadwaita).
    if python3 -c 'import gi; gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1")' 2>/dev/null; then
        cat << EOF > "$APPS_DIR/io.github.jabern.RhinoOnLinux.desktop"
[Desktop Entry]
Name=Rhino on Linux
GenericName=Rhino setup and maintenance
Comment=Install, update, repair or uninstall Rhino
Exec=python3 "$(dirname "$SCRIPT_DIR")/tools/rhino-on-linux.py" %f
Icon=rhino9
Terminal=false
Type=Application
Categories=Utility;
MimeType=application/x-rhino-installer;application/x-rhino-package;application/x-grasshopper-assembly;application/x-grasshopper-userobject;
StartupNotify=true
EOF
    fi

    # File types for models and plug-ins, so double-clicking them works.
    if [ -f "$SCRIPT_DIR/rhino-on-linux-mime.xml" ]; then
        mkdir -p "$HOME/.local/share/mime/packages"
        cp -f "$SCRIPT_DIR/rhino-on-linux-mime.xml" "$HOME/.local/share/mime/packages/io.github.jabern.RhinoOnLinux.xml"
        if command -v update-mime-database >/dev/null 2>&1; then
            update-mime-database "$HOME/.local/share/mime" 2>/dev/null || true
        fi
    fi

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
