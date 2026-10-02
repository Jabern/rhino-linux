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
#   --prefix <PATH>         Wine prefix directory (default: ~/.wine-rhino)
#   --wine <PATH>           Path to custom patched Wine binary
#   --build-wine            Clone Wine and build with all 18 patches automatically
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
WINE_SRC_DIR=""
CUSTOM_WINE=""
RHINO_INSTALLER=""
RUN_RHINO=0

# Default Prefix
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
    echo "=========================================================================="
    echo "  Rhino on Linux Installer"
    echo "=========================================================================="
    echo -e "${NC}"
    echo -e " Distro: ${BOLD}${DISTRO_NAME}${NC}"
    echo -e " Prefix: ${BOLD}${TARGET_PREFIX}${NC}"
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
  --build-wine            Clone and build Wine with patches
  --wine-src <DIR>        Use an existing Wine source directory
  --installer <PATH>      Path to Rhino installer .exe
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
        --build-wine)
            BUILD_WINE=1
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

detect_distro
print_banner

# ------------------------------------------------------------------------------
# Check and Install Distribution Dependencies
# ------------------------------------------------------------------------------
get_distro_deps() {
    case "$DISTRO_FAMILY" in
        arch)
            echo "wine vulkan-icd-loader vulkan-headers dxvk-bin bison flex mingw-w64-gcc libx11 freetype2 gnutls libxext libxcomposite libxdamage"
            ;;
        debian)
            echo "wine64 libvulkan1 vulkan-tools build-essential bison flex gcc-mingw-w64 libx11-dev libfreetype-dev libgnutls28-dev libxext-dev libxcomposite-dev libxdamage-dev dxvk"
            ;;
        fedora)
            echo "wine vulkan-loader-devel gcc make bison flex mingw64-gcc libX11-devel freetype-devel gnutls-devel libXext-devel libXcomposite-devel libXdamage-devel dxvk"
            ;;
        suse)
            echo "wine vulkan-devel gcc make bison flex libX11-devel freetype2-devel libgnutls-devel libXext-devel libXcomposite-devel libXdamage-devel dxvk"
            ;;
        *)
            echo "wine vulkan dxvk bison flex gcc"
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
                sudo pacman -S --needed --noconfirm $deps || true
            else
                pacman -S --needed --noconfirm $deps || true
            fi
            ;;
        debian)
            echo -e "Executing: ${CYAN}sudo apt update && sudo apt install -y $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y $deps || true
            else
                apt update && apt install -y $deps || true
            fi
            ;;
        fedora)
            echo -e "Executing: ${CYAN}sudo dnf install -y $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo dnf install -y $deps || true
            else
                dnf install -y $deps || true
            fi
            ;;
        suse)
            echo -e "Executing: ${CYAN}sudo zypper install -y $deps${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo zypper install -y $deps || true
            else
                zypper install -y $deps || true
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

find_existing_wine() {
    if [ -n "$CUSTOM_WINE" ] && [ -x "$CUSTOM_WINE" ]; then
        WINE_BIN="$CUSTOM_WINE"
    elif [ -n "${WINE:-}" ] && [ -x "$WINE" ]; then
        WINE_BIN="$WINE"
    elif [ -x "/opt/wine-rhino/bin/wine" ]; then
        WINE_BIN="/opt/wine-rhino/bin/wine"
    elif [ -x "$REPO_DIR/build-wine/wine" ]; then
        WINE_BIN="$REPO_DIR/build-wine/wine"
    elif [ -x "/home/jaberm/src/rhino-lab/build-wine/wine" ]; then
        WINE_BIN="/home/jaberm/src/rhino-lab/build-wine/wine"
    elif command -v wine >/dev/null 2>&1; then
        WINE_BIN="$(command -v wine)"
    fi

    if [ -n "$WINE_BIN" ]; then
        WINESERVER_BIN="$(dirname "$WINE_BIN")/wineserver"
        if [ ! -x "$WINESERVER_BIN" ]; then
            WINESERVER_BIN="$(dirname "$WINE_BIN")/server/wineserver"
        fi
        if [ ! -x "$WINESERVER_BIN" ]; then
            WINESERVER_BIN="$(command -v wineserver 2>/dev/null || echo "wineserver")"
        fi
    fi
}

build_patched_wine() {
    echo -e "\n${BOLD}${BLUE}[Step 2/4] Building Patched Wine from Source...${NC}"
    local src_dir="${WINE_SRC_DIR:-$REPO_DIR/wine-src}"
    local build_dir="$REPO_DIR/build-wine"
    local prefix_dir="/opt/wine-rhino"

    if [ ! -d "$src_dir" ]; then
        echo -e "Cloning Wine 11.x repository into ${CYAN}$src_dir${NC}..."
        git clone --depth 1 --branch wine-11.18 https://gitlab.winehq.org/wine/wine.git "$src_dir" || \
        git clone --depth 1 https://gitlab.winehq.org/wine/wine.git "$src_dir"
    fi

    echo "Applying Rhino 18-patch set to $src_dir..."
    cd "$src_dir"
    for patch_file in "$REPO_DIR"/patches/{0[1-9],1[0-5],1[7-8]}-*.patch; do
        patch_name="$(basename "$patch_file")"
        if patch -p1 --dry-run -R -N < "$patch_file" >/dev/null 2>&1; then
            echo -e " ${GREEN}[ALREADY APPLIED]${NC} $patch_name"
        elif patch -p1 --dry-run -N < "$patch_file" >/dev/null 2>&1; then
            patch -p1 -N < "$patch_file" >/dev/null
            echo -e " ${GREEN}[APPLIED]${NC} $patch_name"
        else
            echo -e " ${YELLOW}[SKIPPED/CONFLICT]${NC} $patch_name (dry-run check failed)"
        fi
    done

    mkdir -p "$build_dir"
    cd "$build_dir"
    echo "Configuring Wine 64-bit..."
    "$src_dir/configure" --enable-win64 --prefix="$prefix_dir" --without-capi

    echo "Compiling Wine with $(nproc) parallel jobs..."
    make -j"$(nproc)"

    WINE_BIN="$build_dir/wine"
    WINESERVER_BIN="$build_dir/server/wineserver"
    cd "$REPO_DIR"
    echo -e "${GREEN}Wine build completed successfully: $WINE_BIN${NC}"
}

find_existing_wine

if [ "$BUILD_WINE" -eq 1 ]; then
    build_patched_wine
elif [ -z "$WINE_BIN" ]; then
    echo -e "\n${BOLD}${YELLOW}[Step 2/4] No Wine binary found on system.${NC}"
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        echo "Auto-triggering Wine source build..."
        build_patched_wine
    else
        read -rp "Would you like to automatically clone & build patched Wine now? [Y/n] " ans
        if [[ "${ans:-y}" =~ ^[Yy] ]]; then
            build_patched_wine
        else
            echo -e "${RED}Error: Wine binary required to continue. Install Wine or specify --wine <PATH>.${NC}"
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
"$REPO_DIR/tools/deploy-rhino.sh" --prefix "$TARGET_PREFIX" --wine "$WINE_BIN"

# ------------------------------------------------------------------------------
# Application Installation (Optional)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[Step 4/4] Checking Application Status...${NC}"
RHINO_EXE="$TARGET_PREFIX/drive_c/Program Files/Rhino 9 WIP/System/Rhino.exe"

if [ -n "$RHINO_INSTALLER" ]; then
    if [ -f "$RHINO_INSTALLER" ]; then
        echo -e "Launching Rhino Installer: ${CYAN}$RHINO_INSTALLER${NC}..."
        "$WINE_BIN" "$RHINO_INSTALLER"
        timeout 5 "$WINESERVER_BIN" -w 2>/dev/null || true
        # Re-run deployment script to patch greeting & configs
        "$REPO_DIR/tools/deploy-rhino.sh" --prefix "$TARGET_PREFIX" --wine "$WINE_BIN"
    else
        echo -e "${RED}Error: Installer not found at: $RHINO_INSTALLER${NC}"
    fi
fi

if [ -f "$RHINO_EXE" ]; then
    echo -e " ${GREEN}[PASS]${NC} Rhinoceros detected in prefix."
else
    echo -e " ${YELLOW}[INFO]${NC} Rhino executable not found yet."
    echo "        To install Rhino, download your installer and run:"
    echo -e "        ${CYAN}./install.sh --installer /path/to/rhino_installer.exe${NC}"
    echo -e "        or directly: ${CYAN}rhino-9 /path/to/rhino_installer.exe${NC}"
fi

# Ensure launcher symlink exists in repo root
ln -sf "tools/rhino-9" "$REPO_DIR/rhino-9"

echo -e "\n${BOLD}${GREEN}==========================================================================${NC}"
echo -e "${BOLD}${GREEN}  Setup Complete!${NC}"
echo -e "${BOLD}${GREEN}==========================================================================${NC}"
echo -e " Prefix  : ${BOLD}$TARGET_PREFIX${NC}"
echo -e " Wine    : ${BOLD}$WINE_BIN${NC}"
echo -e " Launcher: ${BOLD}rhino-9${NC} or ${BOLD}./rhino-9${NC}"
echo "=========================================================================="

if [ "$RUN_RHINO" -eq 1 ]; then
    echo -e "\n${BOLD}${CYAN}Launching Rhinoceros...${NC}"
    exec "$REPO_DIR/tools/rhino-9"
elif [ -f "$RHINO_EXE" ] && [ "$NON_INTERACTIVE" -eq 0 ]; then
    echo ""
    read -rp "Would you like to launch Rhino now? [Y/n] " run_ans
    if [[ "${run_ans:-y}" =~ ^[Yy] ]]; then
        exec "$REPO_DIR/tools/rhino-9"
    fi
fi
