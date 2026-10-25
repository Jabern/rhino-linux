#!/usr/bin/env bash
# install-plugin.sh — Install a Rhino or Grasshopper plug-in into the Rhino prefix.
#
# Usage:
#   install-plugin.sh [--version 7|8|9] <file>
#   (default: the newest installed Rhino)
#
# Supported files:
#   .rhi            Rhino Installer Engine package (installed silently by McNeel's rhiexec)
#   .yak            Package Manager package (installed by Rhino's own Yak.exe)
#   .gha .ghuser    Grasshopper component / user object (copied to Grasshopper's folders)
#   .exe .msi       Windows installer (runs inside the Rhino prefix with its own wizard)
#   .zip            any of the above, unpacked first
#
# Exit codes: 0 installed, 1 failed, 2 unsupported file, 3 Rhino is running.
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=rhino-versions.sh
. "$SCRIPT_DIR/rhino-versions.sh"

RHINO_VERSION="${RHINO_VERSION:-}"
if [ "${1:-}" = "--version" ]; then
    RHINO_VERSION="${2:-}"
    shift 2
fi
if [ "$#" -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
fi
FILE="$(realpath "$1")"
if [ ! -f "$FILE" ]; then
    echo "Error: file not found: $1"
    exit 1
fi

[ -n "$RHINO_VERSION" ] || RHINO_VERSION="$(rhino_newest_version)"
if [ -z "$RHINO_VERSION" ]; then
    echo "Error: Rhino is not installed yet."
    exit 1
fi
WINE_BIN="$(rhino_config_get RHINO_WINE)"
WINE_BIN="${WINE_BIN:-$DATA_HOME/wine-rhino/bin/wine}"
export WINEPREFIX="$(rhino_prefix_for "$RHINO_VERSION")" WINEDEBUG="${WINEDEBUG:--all}"
unset WINEDLLOVERRIDES

if [ ! -x "$WINE_BIN" ] || ! RHINO_NAME="$(find_rhino_dir "$WINEPREFIX" "$RHINO_VERSION")"; then
    echo "Error: Rhino is not installed yet (prefix: $WINEPREFIX)."
    exit 1
fi

ROAMING="$WINEPREFIX/drive_c/users/$(id -un)/AppData/Roaming"
RHIEXEC='C:\Program Files\McNeel\Rhino Installer Engine\x64\rhiexec.exe'
YAK="C:\\Program Files\\$RHINO_NAME\\System\\Yak.exe"
WORK="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/rhino-plugin-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Ask the prefix's wineserver: unlike pgrep, this also sees a Rhino started from
# another Flatpak instance, which runs in its own PID namespace.
rhino_running() {
    "$WINE_BIN" tasklist /fi "imagename eq Rhino.exe" /fo csv /nh 2>/dev/null | grep -qi '"Rhino\.exe"'
}

winpath() {
    printf 'Z:%s' "${1//\//\\}"
}

install_rhi() {
    local log="$WORK/rhiexec.log"
    echo "Installing Rhino plug-in package $(basename "$1")..."
    "$WINE_BIN" "$RHIEXEC" /silent "/logfile=$(winpath "$log")" "$(winpath "$1")" || true
    "${WINE_BIN%/wine}/wineserver" -w 2>/dev/null || true
    if grep -q 'Exiting installation with return code Success' "$log" 2>/dev/null; then
        grep -oE "Setting FileName to '[^']+'" "$log" | sed "s/Setting FileName to /  Registered: /" || true
        return 0
    fi
    echo "The Rhino Installer Engine reported a problem:"
    grep -E '\t(Error|Warning)\t' "$log" 2>/dev/null | cut -f3- | tail -15 || tail -15 "$log" 2>/dev/null || true
    return 1
}

install_yak() {
    local manifest name version source="$WORK/yak-source"
    manifest="$(python3 -c 'import sys, zipfile; print(zipfile.ZipFile(sys.argv[1]).read("manifest.yml").decode())' "$1" 2>/dev/null)" || {
        echo "Error: $(basename "$1") is not a valid package (no manifest.yml)."
        return 1
    }
    name="$(printf '%s\n' "$manifest" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d "\"'\r")"
    version="$(printf '%s\n' "$manifest" | sed -n 's/^version:[[:space:]]*//p' | head -1 | tr -d "\"'\r")"
    echo "Installing package $name $version..."
    mkdir -p "$source"
    cp -f "$1" "$source/"
    "$WINE_BIN" "$YAK" install --source="$(winpath "$source")" "$name" "$version"
}

install_grasshopper() {
    local kind="$1" src="$2" dest
    if [ "$kind" = "gha" ]; then dest="$ROAMING/Grasshopper/Libraries"; else dest="$ROAMING/Grasshopper/UserObjects"; fi
    mkdir -p "$dest"
    if [ -d "$src" ]; then
        echo "Copying Grasshopper add-on folder $(basename "$src") to $dest..."
        rm -rf "${dest:?}/$(basename "$src")"
        cp -a "$src" "$dest/"
    else
        echo "Copying $(basename "$src") to $dest..."
        cp -f "$src" "$dest/"
    fi
}

install_windows_installer() {
    echo "Running the Windows installer $(basename "$1")..."
    echo "Follow its steps. Keep the default install location."
    case "${1,,}" in
        *.msi) "$WINE_BIN" msiexec /i "$(winpath "$1")" ;;
        *)     "$WINE_BIN" "$(winpath "$1")" ;;
    esac
    "${WINE_BIN%/wine}/wineserver" -w 2>/dev/null || true
}

install_zip() {
    local dir="$WORK/zip" found=0 f
    echo "Unpacking $(basename "$1")..."
    python3 -m zipfile -e "$1" "$dir"
    while IFS= read -r -d '' f; do
        found=1
        install_one "$f"
    done < <(find "$dir" -type f \( -iname '*.rhi' -o -iname '*.yak' -o -iname '*.exe' -o -iname '*.msi' \) -print0 | sort -z)
    # Grasshopper add-ons often ship .gha files with helper DLLs: copy their whole folder.
    if [ "$found" -eq 0 ]; then
        local gha_dirs
        gha_dirs="$(find "$dir" -type f -iname '*.gha' -printf '%h\n' | sort -u)"
        if [ -n "$gha_dirs" ]; then
            found=1
            while IFS= read -r f; do
                if [ "$f" = "$dir" ]; then
                    mv "$dir" "$WORK/$(basename "${1%.*}")"
                    install_grasshopper gha "$WORK/$(basename "${1%.*}")"
                    return
                fi
                install_grasshopper gha "$f"
            done <<< "$gha_dirs"
        fi
        while IFS= read -r -d '' f; do
            found=1
            install_grasshopper ghuser "$f"
        done < <(find "$dir" -type f -iname '*.ghuser' -print0 2>/dev/null)
    fi
    if [ "$found" -eq 0 ]; then
        echo "Error: no Rhino or Grasshopper plug-in was found inside $(basename "$1")."
        exit 2
    fi
}

install_one() {
    case "${1,,}" in
        *.rhi)    install_rhi "$1" ;;
        *.yak)    install_yak "$1" ;;
        *.gha)    install_grasshopper gha "$1" ;;
        *.ghuser) install_grasshopper ghuser "$1" ;;
        *.exe|*.msi) install_windows_installer "$1" ;;
        *.zip)    install_zip "$1" ;;
        *)
            echo "Error: $(basename "$1") is not a Rhino plug-in this tool can install."
            echo "Supported: .rhi .yak .gha .ghuser .exe .msi .zip"
            exit 2 ;;
    esac
}

if rhino_running; then
    echo "Rhino is running. Close Rhino, then install the plug-in again."
    exit 3
fi

if install_one "$FILE"; then
    echo "Plug-in installed. It is available the next time Rhino starts."
else
    echo "Error: the plug-in could not be installed."
    exit 1
fi
