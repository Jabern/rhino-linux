# shellcheck shell=bash
# rhino-versions.sh — Rhino major versions and where each one lives.
# Sourced by install.sh, deploy-rhino.sh, install-plugin.sh and rhino-linux;
# tools/rhino-on-linux.py follows the same rules.
#
# Every major version gets its own Wine prefix, so Rhino 7's .NET Framework
# setup (mscoree=native for the whole prefix) never touches Rhino 8 or 9, and
# each version can be repaired or uninstalled on its own. All of them share one
# Wine runtime. The single prefix of earlier releases is kept for the version
# it already holds.

RHINO_VERSIONS="9 8 7"   # newest first

RHINO_CONFIG_FILE="${RHINO_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/rhino-linux/config}"

# Program Files folders of a major version, '|'-separated, preferred first.
rhino_dir_names() {
    case "$1" in
        9) echo "Rhino 9|Rhino 9 WIP" ;;
        8) echo "Rhino 8" ;;
        7) echo "Rhino 7" ;;
    esac
}

# Rhino's folder under Program Files in prefix $1, for the versions in $2
# (default: any, newest first). Prints e.g. "Rhino 8".
find_rhino_dir() {
    local prefix="$1" versions="${2:-$RHINO_VERSIONS}" v name
    local -a names
    for v in $versions; do
        IFS='|' read -ra names <<< "$(rhino_dir_names "$v")"
        for name in "${names[@]}"; do
            if [ -f "$prefix/drive_c/Program Files/$name/System/Rhino.exe" ]; then
                printf '%s\n' "$name"
                return 0
            fi
        done
    done
    return 1
}

# Major version of a Program Files folder name ("Rhino 9 WIP" -> 9).
rhino_version_of_dir() {
    case "$1" in
        "Rhino 9"*) echo 9 ;;
        "Rhino 8"*) echo 8 ;;
        "Rhino 7"*) echo 7 ;;
    esac
}

# Major version from McNeel's installer names: rhino_en-us_8.36.26293.11001.exe,
# rhino_9.0.26258.12303.exe, rhino_en-us_7.38.24338.17001.exe.
rhino_version_from_installer() {
    local base
    base="$(basename "$1" | tr '[:upper:]' '[:lower:]')"
    if [[ "$base" =~ ^rhino[_-]([a-z][a-z]-[a-z][a-z][_-])?([0-9]+)\. ]]; then
        case "${BASH_REMATCH[2]}" in 7|8|9) echo "${BASH_REMATCH[2]}" ;; esac
    fi
}

# Read one KEY from the config file, without sourcing it.
rhino_config_get() {
    [ -f "$RHINO_CONFIG_FILE" ] || return 0
    sed -n "s/^$1=\"\\(.*\\)\"\$/\\1/p" "$RHINO_CONFIG_FILE" | tail -n 1
}

# Set KEY="VALUE" in the config file, keeping every other line.
rhino_config_set() {
    local key="$1" value="$2" tmp
    mkdir -p "$(dirname "$RHINO_CONFIG_FILE")"
    tmp="$(mktemp "$RHINO_CONFIG_FILE.XXXXXX")"
    if [ -f "$RHINO_CONFIG_FILE" ]; then
        grep -v "^$key=" "$RHINO_CONFIG_FILE" > "$tmp" || true
    else
        echo "# Rhino on Linux configuration (written by deploy-rhino.sh)" > "$tmp"
    fi
    printf '%s="%s"\n' "$key" "$value" >> "$tmp"
    mv -f "$tmp" "$RHINO_CONFIG_FILE"
}

# The single prefix of releases before 1.2 (or a custom --prefix saved then).
rhino_legacy_prefix() {
    local saved
    saved="$(rhino_config_get RHINO_PREFIX)"
    if [ -n "$saved" ]; then
        echo "$saved"
    elif [ -n "${FLATPAK_ID:-}" ]; then
        echo "$XDG_DATA_HOME/prefix"
    else
        echo "$HOME/.wine-rhino"
    fi
}

# Prefix of major version $1: a saved RHINO_PREFIX_<N>, else the legacy prefix
# when it already holds that version, else a prefix of its own.
rhino_prefix_for() {
    local v="$1" saved legacy
    saved="$(rhino_config_get "RHINO_PREFIX_$v")"
    if [ -n "$saved" ]; then
        echo "$saved"
        return
    fi
    legacy="$(rhino_legacy_prefix)"
    if find_rhino_dir "$legacy" "$v" >/dev/null; then
        echo "$legacy"
    elif [ -n "${FLATPAK_ID:-}" ]; then
        echo "$XDG_DATA_HOME/prefix-rhino$v"
    else
        echo "$HOME/.wine-rhino$v"
    fi
}

# Installed major versions, newest first.
rhino_installed_versions() {
    local v
    for v in $RHINO_VERSIONS; do
        if find_rhino_dir "$(rhino_prefix_for "$v")" "$v" >/dev/null; then
            printf '%s\n' "$v"
        fi
    done
}

# Newest installed major version, or nothing.
rhino_newest_version() {
    local v
    for v in $RHINO_VERSIONS; do
        if find_rhino_dir "$(rhino_prefix_for "$v")" "$v" >/dev/null; then
            echo "$v"
            return 0
        fi
    done
    return 0
}

# Menu entry and icon of version $1, in the host's ~/.local/share (HOME is the
# real home folder in the Flatpak too).
rhino_menu_entry_file() {
    if [ -n "${FLATPAK_ID:-}" ]; then
        echo "$HOME/.local/share/applications/$FLATPAK_ID.Rhino$1.desktop"
    else
        echo "$HOME/.local/share/applications/rhino-$1-version.desktop"
    fi
}
rhino_menu_icon_name() {
    if [ -n "${FLATPAK_ID:-}" ]; then echo "$FLATPAK_ID.Rhino$1"; else echo "rhino-on-linux-rhino$1"; fi
}
# A Flatpak runs nothing when it is uninstalled: its icons stay in its own data
# folder, which "flatpak uninstall --delete-data" removes with it.
if [ -n "${FLATPAK_ID:-}" ]; then
    RHINO_ICON_DIR="${XDG_DATA_HOME:-$HOME/.var/app/$FLATPAK_ID/data}/icons"
else
    RHINO_ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
fi

# The host path of the Flatpak's rhino-linux command, through the deployment's
# current/active links: it follows updates and goes away when the app is
# uninstalled, so menus hide entries whose TryExec points to it from then on.
rhino_flatpak_command_path() {
    local app_path
    app_path="$(sed -n 's/^app-path=//p' /.flatpak-info 2>/dev/null)"
    # app-path is <installation>/app/<id>/<arch>/<branch>/<commit>/files
    [ -n "$app_path" ] && echo "${app_path%/*/*/*/*}/current/active/files/bin/rhino-linux"
}

# One menu entry per installed version, named after its folder ("Rhino 9 WIP"),
# with the icon of its own Rhino.exe and the window class rhino-linux gives it
# (WINE_WM_CLASS=rhinoN), so menus and taskbars keep the versions apart as on
# Windows. Entries of versions no longer installed are removed.
rhino_write_menu_entries() {
    local tools v prefix name file icon exec_cmd fallback_icon try_exec=""
    tools="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -n "${FLATPAK_ID:-}" ]; then
        exec_cmd="flatpak run --command=rhino-linux $FLATPAK_ID"
        fallback_icon="$FLATPAK_ID"
        try_exec="$(rhino_flatpak_command_path)"
    else
        exec_cmd="$HOME/.local/bin/rhino-linux"
        fallback_icon="rhino9"
    fi
    mkdir -p "$HOME/.local/share/applications" "$RHINO_ICON_DIR"
    for v in $RHINO_VERSIONS; do
        file="$(rhino_menu_entry_file "$v")"
        icon="$(rhino_menu_icon_name "$v")"
        prefix="$(rhino_prefix_for "$v")"
        # where Flatpak versions before 1.3.1 put their icons
        [ -n "${FLATPAK_ID:-}" ] && rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/$icon.png"
        if ! name="$(find_rhino_dir "$prefix" "$v")"; then
            rm -f "$file" "$RHINO_ICON_DIR/$icon.png"
            continue
        fi
        # A full path: running desktops (Cinnamon) do not rescan the icon theme
        # when a file is added to one of its size folders.
        if python3 -I "$tools/exe-icon.py" "$prefix/drive_c/Program Files/$name/System/Rhino.exe" \
                "$RHINO_ICON_DIR/$icon.png" >/dev/null 2>&1; then
            icon="$RHINO_ICON_DIR/$icon.png"
        else
            icon="$fallback_icon"
        fi
        cat > "$file" << ENTRY
[Desktop Entry]
Name=$name
GenericName=3D CAD Modeler
Comment=Design, model and fabricate with $name
Exec=$exec_cmd --version $v %F
Icon=$icon
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=application/x-3dm;
StartupWMClass=rhino$v
StartupNotify=true
ENTRY
        [ -n "$try_exec" ] && sed -i "/^Exec=/a TryExec=$try_exec" "$file"
        chmod +x "$file"
    done
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
}
