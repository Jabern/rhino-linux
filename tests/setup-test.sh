#!/usr/bin/env bash
# setup-test.sh — install Rhino on Linux into a throwaway home folder, the way a new
# user does (install.sh -y, release runtime, fresh prefix), and check the result.
# Rhino itself is not installed; a stand-in Rhino.exe covers the "Rhino present" paths.
#
# Usage: tests/setup-test.sh        (needs curl, tar, xz, cabextract; mingw-w64 optional)
# Leaves nothing behind; set KEEP=1 to keep the test home for inspection.
set -uo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/rhino-setup-test-XXXXXX")"
# Work on what a fresh clone contains: no local Wine build (build-wine/ is ignored),
# so install.sh downloads the release runtime like it does for users.
REPO="$T/rhino-linux"
mkdir -p "$REPO"
git -C "$SOURCE" ls-files -z --cached --others --exclude-standard | (cd "$SOURCE" && xargs -0 cp --parents -t "$REPO")
FAILED=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILED=$((FAILED + 1)); }
check() { local what="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$what"; else fail "$what"; fi; }
cleanup() { [ -n "${KEEP:-}" ] && { echo "Test home kept in $T"; return; }; rm -rf "$T"; }
trap cleanup EXIT

# Same environment a fresh user session has, without touching the real home folder.
in_home() { env -i PATH=/usr/bin:/bin HOME="$T" USER="${USER:-user}" TMPDIR="$T/tmp" "$@"; }
mkdir -p "$T/tmp"

PREFIX="$T/.wine-rhino"
RUNTIME="$T/.local/share/wine-rhino"
WINE="$RUNTIME/bin/wine"
wine_run() { in_home WINEPREFIX="$PREFIX" WINEDEBUG=-all "$WINE" "$@"; }
stop_prefix() { in_home WINEPREFIX="$PREFIX" "$RUNTIME/bin/wineserver" -k 2>/dev/null; sleep 2; }

echo "== Fresh install (install.sh -y)"
if in_home bash "$REPO/install.sh" -y > "$T/install.log" 2>&1; then pass "install.sh finishes"
else
    fail "install.sh finishes"
    echo "----- install.sh, runtime step:"
    sed -n '/Step 2\/4/,/Step 3\/4/p' "$T/install.log" | grep -v '%' | head -40
    echo "----- system:"
    uname -srm; grep -m1 'model name' /proc/cpuinfo
    echo "mmap_min_addr=$(cat /proc/sys/vm/mmap_min_addr) overcommit=$(cat /proc/sys/vm/overcommit_memory)" \
         "max_map_count=$(cat /proc/sys/vm/max_map_count) la57=$(grep -c la57 /proc/cpuinfo | head -1)"
    echo "----- install.sh, last lines:"
    tail -15 "$T/install.log"
    echo "-----"
fi
stop_prefix

check "Wine runtime installed" test -x "$WINE"
check "prefix has 32-bit system files (WoW64)" test -f "$PREFIX/drive_c/windows/syswow64/kernel32.dll"
check "DXVK is the native d3d11" bash -c "! grep -qa 'Wine builtin DLL' '$PREFIX/drive_c/windows/system32/d3d11.dll'"
check "Arial is installed" test -f "$PREFIX/drive_c/windows/Fonts/arial.ttf"
check "launcher config saved" grep -q "RHINO_PREFIX=" "$T/.config/rhino-linux/config"
check "rhino-9 launcher installed" test -x "$T/.local/bin/rhino-9"
check "Tahoma registered by file name" grep -q '"Tahoma (TrueType)"="tahoma.ttf"' "$PREFIX/system.reg"
check "Wine's menu builder is off" grep -q '"winemenubuilder.exe"=""' "$PREFIX/user.reg"

TAHOMA_EXE=""
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    TAHOMA_EXE="$T/dwrite-tahoma.exe"
    x86_64-w64-mingw32-gcc -O2 -o "$TAHOMA_EXE" "$REPO/tests/dwrite-tahoma.c" -ldwrite
    check "DirectWrite finds Tahoma" wine_run "$TAHOMA_EXE"
    stop_prefix
else
    echo "SKIP  DirectWrite checks (no x86_64-w64-mingw32-gcc)"
fi

echo "== Repair with Rhino present (stand-in Rhino.exe)"
RHINO_SYS="$PREFIX/drive_c/Program Files/Rhino 9/System"
mkdir -p "$RHINO_SYS" && touch "$RHINO_SYS/Rhino.exe"
DESKTOP="$(readlink -f "$PREFIX/drive_c/users/${USER:-user}/Desktop" 2>/dev/null || true)"
if [ -z "$DESKTOP" ] || [ ! -d "$PREFIX/drive_c/users" ]; then
    echo "The fresh install left no usable prefix; skipping the repair checks."
    echo; echo "$FAILED check(s) failed."; exit 1
fi
mkdir -p "$DESKTOP" && touch "$DESKTOP/Rhino 9.lnk" "$DESKTOP/notes.txt"
if in_home bash "$REPO/tools/deploy-rhino.sh" --prefix "$PREFIX" --wine "$WINE" --skip-desktop > "$T/repair.log" 2>&1
then pass "deploy-rhino.sh repair finishes"; else fail "deploy-rhino.sh repair finishes"; tail -15 "$T/repair.log"; fi
stop_prefix
check "DXVK config placed next to Rhino.exe" test -f "$RHINO_SYS/dxvk.conf"
check "installer's Desktop shortcut removed" test ! -e "$DESKTOP/Rhino 9.lnk"
check "other Desktop files kept" test -e "$DESKTOP/notes.txt"

printf 'not a plug-in\n' > "$T/readme.txt"
in_home WINEPREFIX="$PREFIX" bash "$REPO/tools/install-plugin.sh" "$T/readme.txt" > "$T/plugin.log" 2>&1
code=$?
if [ "$code" -eq 2 ]; then pass "install-plugin.sh rejects a non-plug-in"
else fail "install-plugin.sh rejects a non-plug-in (exit $code)"; tail -5 "$T/plugin.log"; fi
stop_prefix

if [ -n "$TAHOMA_EXE" ]; then
    echo "== Wine runtime moved to another folder"
    mv "$RUNTIME" "$T/moved-runtime"
    if in_home WINEPREFIX="$PREFIX" WINEDEBUG=-all "$T/moved-runtime/bin/wine" "$TAHOMA_EXE" >/dev/null 2>&1
    then pass "DirectWrite still finds Tahoma"; else fail "DirectWrite still finds Tahoma"; fi
    in_home WINEPREFIX="$PREFIX" "$T/moved-runtime/bin/wineserver" -k 2>/dev/null
    mv "$T/moved-runtime" "$RUNTIME"
fi

echo
if [ "$FAILED" -eq 0 ]; then echo "All checks passed."; else echo "$FAILED check(s) failed."; fi
exit $(( FAILED > 0 ))
