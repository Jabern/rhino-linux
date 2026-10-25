#!/usr/bin/env bash
# ==============================================================================
# Rhinoceros on Linux — Universal Installer & Environment Configurator
# ==============================================================================
# Supports: Arch Linux / Manjaro, Ubuntu / Debian / Pop!_OS / Mint, Fedora / RHEL, openSUSE
#
# Usage:
#   ./install.sh [OPTIONS]
#
# Options:
#   -y, --yes               Non-interactive mode (auto-accept defaults)
#   --deps                  Check and install distro dependencies
#   --prefix <PATH>         Wine prefix directory (default: one per Rhino version)
#   --version <7|8|9>       Rhino major version (default: from the installer's name)
#   --wine <PATH>           Path to custom patched Wine binary
#   --dxvk-dir <PATH>       Path to custom DXVK 64-bit DLL directory
#   --build-wine            Build Wine from source with the patch stack
#   --wayland               Include optional pure Wayland patch (Patch 16)
#   --no-download           Do not download pre-built Wine (use existing or build)
#   --wine-src <DIR>        Use existing Wine source directory to patch & build
#   --installer <PATH>      Path to Rhino installer executable (.exe)
#   --run                   Launch Rhino immediately after setup
#   -h, --help              Show this help message
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

# Color definitions
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default settings
NON_INTERACTIVE=0
INSTALL_DEPS=0
BUILD_WINE=0
ENABLE_WAYLAND=0
NO_DOWNLOAD=0
WINE_SRC_DIR=""
CUSTOM_WINE=""
CUSTOM_DXVK_DIR=""
RHINO_INSTALLER=""
RUN_RHINO=0
WINE_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wine-rhino"
WINE_RELEASE_URL="https://github.com/Jabern/rhino-linux/releases/download/v1.2.0/wine-rhino-11.18-x86_64.tar.xz"
WINE_RELEASE_SHA256="ed034657823ffcca0480b7a69dff0a514f2b94504f9259b4281b061baeb03a9f"

# Rhino versions and their prefixes (rhino_prefix_for, find_rhino_dir, ...)
# shellcheck source=tools/rhino-versions.sh
. "$REPO_DIR/tools/rhino-versions.sh"

# Prefix: given with --prefix or RHINO_PREFIX, else chosen per Rhino version
# once the version is known (after the options are parsed).
TARGET_PREFIX="${RHINO_PREFIX:-${WINEPREFIX:-}}"
RHINO_VERSION="${RHINO_VERSION:-}"

# Detect Linux Distribution
detect_distro() {
    DISTRO_ID="unknown"
    DISTRO_NAME="Unknown Linux"
    DISTRO_FAMILY="unknown"

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${PRETTY_NAME:-$NAME}"

        case "$DISTRO_ID" in
            arch|manjaro|endeavouros|garuda|artix|arcolinux)
                DISTRO_FAMILY="arch"
                ;;
            ubuntu|debian|pop|linuxmint|elementary|zorin|neon)
                DISTRO_FAMILY="debian"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                DISTRO_FAMILY="fedora"
                ;;
            opensuse*|suse|sles)
                DISTRO_FAMILY="suse"
                ;;
            *)
                if [[ "${ID_LIKE:-}" =~ (arch) ]]; then
                    DISTRO_FAMILY="arch"
                elif [[ "${ID_LIKE:-}" =~ (debian|ubuntu) ]]; then
                    DISTRO_FAMILY="debian"
                elif [[ "${ID_LIKE:-}" =~ (fedora|rhel) ]]; then
                    DISTRO_FAMILY="fedora"
                elif [[ "${ID_LIKE:-}" =~ (suse) ]]; then
                    DISTRO_FAMILY="suse"
                fi
                ;;
        esac
    fi
}

print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "  ____  _     _                               _     _                  "
    echo " |  _ \| |__ (_)_ __   ___   ___  _ __       | |   (_)_ __  _   ___  __"
    echo " | |_) | '_ \| | '_ \ / _ \ / _ \| '_ \ _____| |   | | '_ \| | | \ \/ /"
    echo " |  _ <| | | | | | | | (_) | (_) | | | |_____| |___| | | | | |_| |>  < "
    echo " |_| \_\_| |_|_|_| |_|\___/ \___/|_| |_|     |_____|_|_| |_|\__,_/_/\_\\"
    echo -e "${NC}"
    echo -e " Rhinoceros on Linux — Universal Compatibility & Setup Tool"
    echo -e " Distribution detected: ${BOLD}${DISTRO_NAME}${NC} (${DISTRO_FAMILY})"
    echo "=========================================================================="
}

print_help() {
    cat << 'EOF'
Rhino on Linux — Setup Script

Usage:
  ./install.sh [OPTIONS]

Options:
  -y, --yes               Non-interactive mode (use defaults)
  --deps                  Install distro packages
  --prefix <PATH>         Wine prefix directory (default: ~/.wine-rhino)
  --wine <PATH>           Path to custom Wine binary
  --dxvk-dir <PATH>       Path to custom DXVK 64-bit DLL directory
  --build-wine            Build Wine from source with the patch stack
  --wayland               Include optional pure Wayland patch (Patch 16)
  --no-download           Do not download pre-built Wine (use existing or build)
  --wine-src <DIR>        Use an existing Wine source directory
  --installer <PATH>      Path to Rhino installer .exe
  --version <7|8|9>       Rhino major version (default: from the installer's name);
                          each version gets its own prefix
  --run                   Launch Rhino after setup
  -h, --help              Show this help
EOF
}

# Parse Command Line Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--non-interactive)
            NON_INTERACTIVE=1
            shift
            ;;
        --deps)
            INSTALL_DEPS=1
            shift
            ;;
        --prefix)
            TARGET_PREFIX="$2"
            shift 2
            ;;
        --wine)
            CUSTOM_WINE="$2"
            shift 2
            ;;
        --dxvk-dir)
            CUSTOM_DXVK_DIR="$2"
            shift 2
            ;;
        --build-wine)
            BUILD_WINE=1
            shift
            ;;
        --wayland)
            ENABLE_WAYLAND=1
            shift
            ;;
        --no-download)
            NO_DOWNLOAD=1
            shift
            ;;
        --wine-src)
            WINE_SRC_DIR="$2"
            BUILD_WINE=1
            shift 2
            ;;
        --installer)
            RHINO_INSTALLER="$2"
            shift 2
            ;;
        --version)
            RHINO_VERSION="$2"
            shift 2
            ;;
        --run)
            RUN_RHINO=1
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}" >&2
            echo "Run ./install.sh --help for available options."
            exit 1
            ;;
    esac
done

# Rhino version: given, else from the installer's file name; it picks the prefix.
if [ -z "$RHINO_VERSION" ] && [ -n "$RHINO_INSTALLER" ]; then
    RHINO_VERSION="$(rhino_version_from_installer "$RHINO_INSTALLER")"
fi
case "$RHINO_VERSION" in
    ""|7|8|9) ;;
    *) echo -e "${RED}Error: unknown Rhino version '$RHINO_VERSION' (7, 8 or 9)${NC}" >&2; exit 1 ;;
esac
if [ -z "$TARGET_PREFIX" ]; then
    if [ -n "$RHINO_VERSION" ]; then
        TARGET_PREFIX="$(rhino_prefix_for "$RHINO_VERSION")"
    else
        TARGET_PREFIX="$(rhino_legacy_prefix)"
    fi
fi

detect_distro
print_banner

# ------------------------------------------------------------------------------
# Check and Install Distribution Dependencies
# ------------------------------------------------------------------------------
get_distro_deps() {
    case "$DISTRO_FAMILY" in
        arch)
            echo "wine vulkan-icd-loader vulkan-headers dxvk-bin cabextract bison flex mingw-w64-gcc libx11 freetype2 gnutls libxext libxcomposite libxdamage"
            ;;
        debian)
            echo "wine64 libvulkan1 vulkan-tools build-essential cabextract bison flex gcc-mingw-w64 g++-mingw-w64 libx11-dev libfreetype-dev libgnutls28-dev libxext-dev libxcomposite-dev libxdamage-dev dxvk"
            ;;
        fedora)
            echo "wine vulkan-loader-devel gcc gcc-c++ make cabextract bison flex mingw64-gcc mingw64-gcc-c++ mingw32-gcc mingw32-gcc-c++ libX11-devel freetype-devel gnutls-devel libXext-devel libXcomposite-devel libXdamage-devel dxvk"
            ;;
        suse)
            echo "wine vulkan-devel gcc gcc-c++ make cabextract bison flex libX11-devel freetype2-devel libgnutls-devel libXext-devel libXcomposite-devel libXdamage-devel dxvk"
            ;;
        *)
            echo "wine vulkan dxvk cabextract bison flex gcc"
            ;;
    esac
}

install_dependencies() {
    local deps
    deps="$(get_distro_deps)"
    echo -e "\n${BOLD}${BLUE}[Step 1/4] Checking System Dependencies for ${DISTRO_NAME}...${NC}"

    case "$DISTRO_FAMILY" in
        arch)
            echo -e "Executing: ${CYAN}sudo pacman -S --needed $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm $deps
            else
                pacman -S --needed --noconfirm $deps
            fi
            ;;
        debian)
            echo -e "Executing: ${CYAN}sudo apt update && sudo apt install -y $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y $deps
            else
                apt update && apt install -y $deps
            fi
            ;;
        fedora)
            echo -e "Executing: ${CYAN}sudo dnf install -y $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo dnf install -y $deps
            else
                dnf install -y $deps
            fi
            ;;
        suse)
            echo -e "Executing: ${CYAN}sudo zypper install -y $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo zypper install -y $deps
            else
                zypper install -y $deps
            fi
            ;;
        *)
            echo -e "${YELLOW}Notice: Unknown distribution. Please ensure Wine, Vulkan, and DXVK are installed.${NC}"
            ;;
    esac
}

if [ "$INSTALL_DEPS" -eq 1 ]; then
    install_dependencies
else
    echo -e "\n${BOLD}${BLUE}[Step 1/4] Checking Environment & Drivers...${NC}"
    if command -v vulkaninfo >/dev/null 2>&1; then
        echo -e " ${GREEN}[PASS]${NC} Vulkan runtime detected."
    elif ldconfig -p 2>/dev/null | grep -q "libvulkan.so"; then
        echo -e " ${GREEN}[PASS]${NC} libvulkan detected via ldconfig."
    else
        echo -e " ${YELLOW}[WARN]${NC} Vulkan loader not found. Hardware acceleration may require installing Vulkan drivers."
        echo -e "        Recommended packages: $(get_distro_deps)"
    fi
fi

# ------------------------------------------------------------------------------
# Wine Binary Resolution & Compilation
# ------------------------------------------------------------------------------
WINE_BIN=""
WINESERVER_BIN=""

# The installed runtime records where it came from: the release checksum it was
# extracted from, or "local-build" for --build-wine. An older or unmarked runtime is
# replaced by the current release; a local build is kept.
RUNTIME_STAMP="$WINE_INSTALL_DIR/.rhino-linux-runtime"
runtime_is_current() {
    local stamp
    stamp="$(cat "$RUNTIME_STAMP" 2>/dev/null || true)"
    [ "$stamp" = "$WINE_RELEASE_SHA256" ] || [ "$stamp" = "local-build" ]
}

find_existing_wine() {
    if [ -n "$CUSTOM_WINE" ] && [ -x "$CUSTOM_WINE" ]; then
        WINE_BIN="$CUSTOM_WINE"
    elif [ -n "${WINE:-}" ] && [ -x "$WINE" ]; then
        WINE_BIN="$WINE"
    elif [ -x "$WINE_INSTALL_DIR/bin/wine" ] && runtime_is_current; then
        WINE_BIN="$WINE_INSTALL_DIR/bin/wine"
    elif [ -x "/opt/wine-rhino/bin/wine" ]; then
        WINE_BIN="/opt/wine-rhino/bin/wine"
    elif [ -x "$REPO_DIR/build-wine/wine" ]; then
        WINE_BIN="$REPO_DIR/build-wine/wine"
    fi

    if [ -n "$WINE_BIN" ]; then
        WINESERVER_BIN="$(dirname "$WINE_BIN")/wineserver"
        if [ ! -x "$WINESERVER_BIN" ]; then
            WINESERVER_BIN="$(dirname "$WINE_BIN")/server/wineserver"
        fi
        if [ ! -x "$WINESERVER_BIN" ]; then
            WINESERVER_BIN="$(dirname "$WINE_BIN")/../server/wineserver"
        fi
        if [ ! -x "$WINESERVER_BIN" ]; then
            WINESERVER_BIN="$(command -v wineserver 2>/dev/null || echo "wineserver")"
        fi
    fi
}

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

download_prebuilt_wine() {
    echo -e "\n${BOLD}${BLUE}[Step 2/4] Downloading Pre-built Patched Wine...${NC}"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rhino-linux"
    local tarball="$cache_dir/wine-rhino-11.18-x86_64.tar.xz"
    local temp_tarball="$tarball.part.$$"

    mkdir -p "$cache_dir" "$WINE_INSTALL_DIR"

    # Verify existing cached archive if present
    if [ -f "$tarball" ]; then
        if verify_sha256 "$WINE_RELEASE_SHA256" "$tarball"; then
            echo -e "Using verified cached Wine archive: $tarball"
        else
            echo -e "${YELLOW}Cached Wine archive failed checksum verification. Re-downloading...${NC}"
            rm -f "$tarball"
        fi
    fi

    if [ ! -f "$tarball" ]; then
        echo -e "Fetching pre-compiled Wine runtime (~54 MB)..."
        local fetched=0
        if command -v curl >/dev/null 2>&1; then
            curl -fL --retry 3 --retry-delay 5 --retry-all-errors --progress-bar -o "$temp_tarball" "$WINE_RELEASE_URL" && fetched=1
        elif command -v wget >/dev/null 2>&1; then
            wget --tries=4 --waitretry=5 --show-progress -O "$temp_tarball" "$WINE_RELEASE_URL" && fetched=1
        else
            echo -e "${RED}Error: curl or wget is required to download pre-built Wine.${NC}"
            return 1
        fi
        if [ "$fetched" -ne 1 ]; then
            echo -e "${RED}Error: downloading $WINE_RELEASE_URL failed.${NC}" >&2
            rm -f "$temp_tarball"
            return 1
        fi

        echo "Verifying SHA256 checksum..."
        if ! verify_sha256 "$WINE_RELEASE_SHA256" "$temp_tarball"; then
            echo -e "${RED}Error: SHA256 checksum verification failed for downloaded Wine runtime.${NC}" >&2
            rm -f "$temp_tarball"
            return 1
        fi
        mv -f "$temp_tarball" "$tarball"
    fi

    echo -e "Extracting Wine runtime to ${CYAN}$WINE_INSTALL_DIR${NC}..."
    rm -rf "$WINE_INSTALL_DIR"
    mkdir -p "$WINE_INSTALL_DIR"
    tar -xf "$tarball" -C "$WINE_INSTALL_DIR"
    echo "$WINE_RELEASE_SHA256" > "$RUNTIME_STAMP"

    WINE_BIN="$WINE_INSTALL_DIR/bin/wine"
    WINESERVER_BIN="$WINE_INSTALL_DIR/bin/wineserver"

    local version_out
    if [ -x "$WINE_BIN" ] && version_out="$("$WINE_BIN" --version 2>&1)"; then
        echo -e " ${GREEN}[PASS]${NC} Patched Wine ready: $version_out"
        return 0
    else
        echo -e "${RED}Error: Failed to verify functional Wine binary at $WINE_BIN${NC}" >&2
        [ -n "${version_out:-}" ] && echo "$version_out" | head -10 >&2
        return 1
    fi
}

build_patched_wine() {
    echo -e "\n${BOLD}${BLUE}[Step 2/4] Building Patched Wine from Source...${NC}"
    local src_dir="${WINE_SRC_DIR:-$REPO_DIR/wine-src}"
    local build_dir="$REPO_DIR/build-wine"
    local jobs
    jobs="$(nproc 2>/dev/null || echo 4)"

    if [ ! -d "$src_dir" ]; then
        echo -e "Cloning Wine 11.18 repository into ${CYAN}$src_dir${NC}..."
        git clone --depth 1 --branch wine-11.18 https://gitlab.winehq.org/wine/wine.git "$src_dir"
    fi

    local patch_files=()
    if [ "$ENABLE_WAYLAND" -eq 1 ]; then
        echo "Applying full patch set (including Wayland driver Patch 16)..."
        patch_files=("$REPO_DIR"/patches/*.patch)
    else
        echo "Applying standard patch set for X11 / XWayland (all except Patch 16)..."
        patch_files=("$REPO_DIR"/patches/{0[1-9],1[0-5],1[7-9],2[0-9]}-*.patch)
    fi

    cd "$src_dir"
    for patch_file in "${patch_files[@]}"; do
        patch_name="$(basename "$patch_file")"
        if patch -p1 --dry-run -R -N < "$patch_file" >/dev/null 2>&1; then
            echo -e " ${GREEN}[ALREADY APPLIED]${NC} $patch_name"
        elif patch -p1 --dry-run -N < "$patch_file" >/dev/null 2>&1; then
            patch -p1 -N < "$patch_file" >/dev/null
            echo -e " ${GREEN}[APPLIED]${NC} $patch_name"
        else
            echo -e " ${RED}[FAILED]${NC} $patch_name failed to apply! Aborting build." >&2
            return 1
        fi
    done

    # WoW64 build: the Rhino installer bootstrapper is a 32-bit executable.
    mkdir -p "$build_dir"
    cd "$build_dir"
    # ccache makes rebuilds after a patch change recompile only the touched files.
    local cc_vars=()
    if command -v ccache >/dev/null 2>&1; then
        echo "Using ccache for host and PE (mingw) compilers."
        cc_vars=(CC="ccache gcc"
                 CXX="ccache g++"
                 i386_CC="ccache i686-w64-mingw32-gcc"
                 i386_CXX="ccache i686-w64-mingw32-g++"
                 x86_64_CC="ccache x86_64-w64-mingw32-gcc"
                 x86_64_CXX="ccache x86_64-w64-mingw32-g++")
    else
        cc_vars=(CXX="g++"
                 i386_CC="i686-w64-mingw32-gcc"
                 i386_CXX="i686-w64-mingw32-g++"
                 x86_64_CC="x86_64-w64-mingw32-gcc"
                 x86_64_CXX="x86_64-w64-mingw32-g++")
    fi

    local cppflags=()
    if [ -d "$REPO_DIR/kernel-headers" ]; then
        cppflags=(CPPFLAGS="-I$REPO_DIR/kernel-headers")
    fi

    echo "Configuring Wine (WoW64: i386 + x86_64)..."
    "$src_dir/configure" --prefix="$WINE_INSTALL_DIR" --enable-archs=i386,x86_64 \
        --disable-tests --without-capi --without-gstreamer "${cppflags[@]}" "${cc_vars[@]}"

    # Viewport repaint after maximize/resize depends on XDamage; ntsync on the kernel header.
    if ! grep -q '^#define SONAME_LIBXDAMAGE ' include/config.h; then
        echo -e "${RED}Error: libXdamage development files not found; the viewport repaint fix would be compiled out.${NC}" >&2
        return 1
    fi
    if ! grep -q '^#define HAVE_LINUX_NTSYNC_H 1' include/config.h; then
        echo -e "${YELLOW}Warning: linux/ntsync.h not found; building without ntsync support.${NC}"
    fi
    if ! grep -q 'dlls/icu/x86_64-windows/icu.dll' Makefile; then
        echo -e "${RED}Error: 64-bit ICU (icu.dll) was not enabled; MinGW C++ compiler (g++-mingw-w64 / mingw64-gcc-c++) is required for .NET globalization.${NC}" >&2
        return 1
    fi

    echo "Compiling Wine with $jobs parallel jobs..."
    make -j"$jobs"
    make install

    # Verify icu.dll exists in the installed wine tree
    if [ ! -s "$WINE_INSTALL_DIR/lib/wine/x86_64-windows/icu.dll" ]; then
        echo -e "${RED}Error: icu.dll not found in $WINE_INSTALL_DIR/lib/wine/x86_64-windows/; Wine will fail to run .NET 9 apps like Rhino.${NC}" >&2
        return 1
    fi

    echo "local-build" > "$RUNTIME_STAMP"

    WINE_BIN="$WINE_INSTALL_DIR/bin/wine"
    WINESERVER_BIN="$WINE_INSTALL_DIR/bin/wineserver"
    cd "$REPO_DIR"
    echo -e "${GREEN}Wine build completed successfully: $("$WINE_BIN" --version)${NC}"
}

find_existing_wine

if [ "$BUILD_WINE" -eq 1 ]; then
    build_patched_wine
elif [ -z "$WINE_BIN" ]; then
    if [ "$NO_DOWNLOAD" -eq 1 ]; then
        if command -v wine >/dev/null 2>&1; then
            WINE_BIN="$(command -v wine)"
            WINESERVER_BIN="$(command -v wineserver 2>/dev/null || echo "wineserver")"
            echo -e "\n${BOLD}${YELLOW}[Step 2/4] Using system Wine (unpatched):${NC} $WINE_BIN"
        else
            echo -e "${RED}Error: No Wine binary found and --no-download was specified.${NC}"
            exit 1
        fi
    else
        # Compiling Wine needs dozens of development packages and about an hour,
        # so a failed download stops here instead of starting a source build.
        if ! download_prebuilt_wine; then
            echo -e "${RED}Could not download the Wine runtime.${NC}" >&2
            echo "Check your internet connection and run the installer again; finished steps are kept." >&2
            echo "(Experts can build Wine from source instead with: ./install.sh --build-wine)" >&2
            exit 1
        fi
    fi
else
    echo -e "\n${BOLD}${BLUE}[Step 2/4] Selected Wine Binary:${NC} ${GREEN}$WINE_BIN${NC}"
fi

# ------------------------------------------------------------------------------
# Wine Prefix Initialization & Registry Deployment
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[Step 3/4] Deploying Prefix & Performance Tuning...${NC}"
export WINE="$WINE_BIN"
export WINEPREFIX="$TARGET_PREFIX"
export RHINO_PREFIX="$TARGET_PREFIX"

# Run deployment script
deploy_cmd=("$REPO_DIR/tools/deploy-rhino.sh" --prefix "$TARGET_PREFIX" --wine "$WINE_BIN")
if [ -n "$RHINO_VERSION" ]; then
    deploy_cmd+=(--version "$RHINO_VERSION")
fi
if [ -n "$CUSTOM_DXVK_DIR" ]; then
    deploy_cmd+=(--dxvk-dir "$CUSTOM_DXVK_DIR")
fi
"${deploy_cmd[@]}"

# ------------------------------------------------------------------------------
# Application Installation (Optional)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[Step 4/4] Checking Application Status...${NC}"
rhino_present() { find_rhino_dir "$TARGET_PREFIX" "${RHINO_VERSION:-$RHINO_VERSIONS}" >/dev/null; }

if [ -n "$RHINO_INSTALLER" ]; then
    if [ -f "$RHINO_INSTALLER" ]; then
        echo -e "Launching Rhino Installer: ${CYAN}$RHINO_INSTALLER${NC}..."
        installer_flags=()
        if [ "$NON_INTERACTIVE" -eq 1 ]; then
            installer_flags+=(/passive /norestart)
        fi
        installer_env=()
        if [ "$RHINO_VERSION" = 7 ]; then
            # Rhino 7's MSI runs .NET custom actions in a 32-bit helper that does
            # not see the registry's mscoree=native and fails with 0x643; the
            # environment reaches every process the installer starts.
            installer_env=(WINEDLLOVERRIDES="mscoree=native;winemenubuilder.exe=d")
        fi
        env "${installer_env[@]}" "$WINE_BIN" "$RHINO_INSTALLER" "${installer_flags[@]}" || [ $? -eq 3010 ]
        # Wait for any lingering msiexec tasks to complete
        while "$WINESERVER_BIN" -k 0 2>/dev/null && pgrep -f -u "$UID" "msiexec" >/dev/null 2>&1; do
            sleep 2
        done
        timeout 10 "$WINESERVER_BIN" -w 2>/dev/null || true
        # Re-run deployment script to patch greeting & configs
        "${deploy_cmd[@]}"
    else
        echo -e "${RED}Error: Installer not found at: $RHINO_INSTALLER${NC}"
    fi
fi

if rhino_present; then
    echo -e " ${GREEN}[PASS]${NC} Rhinoceros detected in prefix."
else
    echo -e " ${YELLOW}[INFO]${NC} Rhino executable not found yet."
    echo "        To install Rhino, download your installer and run:"
    echo -e "        ${CYAN}./install.sh --installer /path/to/rhino_installer.exe${NC}"
fi

# Ensure launcher symlink exists in repo root
if [ -w "$REPO_DIR" ]; then ln -sf "tools/rhino-linux" "$REPO_DIR/rhino-linux"; fi

echo -e "\n${BOLD}${GREEN}==========================================================================${NC}"
echo -e "${BOLD}${GREEN}  Setup Complete!${NC}"
echo -e "${BOLD}${GREEN}==========================================================================${NC}"
echo -e " Prefix  : ${BOLD}$TARGET_PREFIX${NC}"
echo -e " Wine    : ${BOLD}$WINE_BIN${NC}"
if [ -n "$RHINO_VERSION" ]; then
    echo -e " Rhino   : ${BOLD}Rhino $RHINO_VERSION${NC}"
    echo -e " Launcher: ${BOLD}rhino-linux --version $RHINO_VERSION${NC}"
else
    echo -e " Launcher: ${BOLD}rhino-linux${NC} or ${BOLD}./rhino-linux${NC}"
fi
echo "=========================================================================="

if [ "$RUN_RHINO" -eq 1 ]; then
    echo -e "\n${BOLD}${CYAN}Launching Rhinoceros...${NC}"
    exec "$REPO_DIR/tools/rhino-linux" ${RHINO_VERSION:+--version "$RHINO_VERSION"}
elif rhino_present && [ "$NON_INTERACTIVE" -eq 0 ]; then
    echo ""
    read -rp "Would you like to launch Rhino now? [Y/n] " run_ans
    if [[ "${run_ans:-y}" =~ ^[Yy] ]]; then
        exec "$REPO_DIR/tools/rhino-linux" ${RHINO_VERSION:+--version "$RHINO_VERSION"}
    fi
fi
