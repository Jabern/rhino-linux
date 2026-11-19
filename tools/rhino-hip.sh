# shellcheck shell=bash
# rhino-hip.sh — Cycles on AMD GPUs: the HIP runtime rhino-linux downloads for them.
# Sourced by deploy-rhino.sh and rhino-linux; tools/rhino-on-linux.py runs it:
#   rhino-hip.sh status PREFIX    prints "gfxNNNN installed|missing", or nothing without a GPU
#   rhino-hip.sh install          downloads and unpacks the runtime
#
# The amdhip64 bridge (gpu-bridges/amdhip64) passes Cycles' HIP calls to Linux. Most systems
# have no ROCm (SteamOS, the Flatpak), so for a GPU Rhino's Cycles has kernels for, we bring
# AMD's HIP runtime ourselves (gpu-bridges/hip-runtime, about 45 MB). On by default for such a
# GPU; RHINO_HIP=0 (the app's switch) turns it off.

HIP_RUNTIME_VERSION="6.4.4"
HIP_RUNTIME_SHA256="6269ccd5af6c5233c30d77af53e4f6159c15321e890d8cc1624782a658a65d50"
HIP_RUNTIME_URL="https://github.com/Jabern/rhino-linux/releases/download/hip-runtime-$HIP_RUNTIME_VERSION/rocm-hip-runtime-$HIP_RUNTIME_VERSION-x86_64.tar.xz"
HIP_RUNTIME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rhino-linux/rocm-hip-runtime-$HIP_RUNTIME_VERSION"

# The GPUs the kernel's compute driver (amdgpu's KFD) offers, as gfx targets (gfx1102). Its
# gfx_target_version is major*10000 + minor*100 + stepping, the stepping a hex digit (gfx90c).
# RHINO_KFD_TOPOLOGY stands in for the sysfs folder in tests.
amd_gpu_targets() {
    local props v
    for props in "${RHINO_KFD_TOPOLOGY:-/sys/class/kfd/kfd/topology}"/nodes/*/properties; do
        v="$(awk '$1 == "gfx_target_version" { print $2 }' "$props" 2>/dev/null)"
        [ -n "$v" ] && [ "$v" -gt 0 ] || continue
        printf 'gfx%d%d%x\n' $((v / 10000)) $((v / 100 % 100)) $((v % 100))
    done
}

# The first GPU Rhino's Cycles in prefix $1 has kernels for (Plug-ins/RhinoCycles/lib/
# kernel_gfxNNNN.fatbin), any installed version; prints nothing when there is none.
hip_supported_gpu() {
    local prefix="$1" target lib
    for target in $(amd_gpu_targets); do
        for lib in "$prefix/drive_c/Program Files/"Rhino*/Plug-ins/RhinoCycles/lib; do
            if [ -f "$lib/kernel_$target.fatbin" ]; then
                printf '%s\n' "$target"
                return 0
            fi
        done
    done
    return 1
}

hip_runtime_installed() {
    [ -e "$HIP_RUNTIME_DIR/lib/libamdhip64.so.6" ]
}

# Download, check and unpack the runtime into HIP_RUNTIME_DIR; earlier versions go.
hip_runtime_install() {
    local cache tarball parent
    hip_runtime_installed && return 0
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/rhino-linux"
    tarball="$cache/rocm-hip-runtime-$HIP_RUNTIME_VERSION-x86_64.tar.xz"
    parent="$(dirname "$HIP_RUNTIME_DIR")"
    mkdir -p "$cache" "$parent" || return 1
    if [ ! -f "$tarball" ] || ! echo "$HIP_RUNTIME_SHA256  $tarball" | sha256sum -c --quiet 2>/dev/null; then
        curl -fL --retry 3 --retry-delay 5 --retry-all-errors -o "$tarball.part" "$HIP_RUNTIME_URL" &&
            echo "$HIP_RUNTIME_SHA256  $tarball.part" | sha256sum -c --quiet &&
            mv -f "$tarball.part" "$tarball" || { rm -f "$tarball.part"; return 1; }
    fi
    rm -rf "$HIP_RUNTIME_DIR.new"
    mkdir -p "$HIP_RUNTIME_DIR.new" &&
        tar -C "$HIP_RUNTIME_DIR.new" --strip-components=1 -xJf "$tarball" &&
        rm -rf "$HIP_RUNTIME_DIR" && mv "$HIP_RUNTIME_DIR.new" "$HIP_RUNTIME_DIR" || { rm -rf "$HIP_RUNTIME_DIR.new"; return 1; }
    find "$parent" -maxdepth 1 -name 'rocm-hip-runtime-*' ! -name "rocm-hip-runtime-$HIP_RUNTIME_VERSION" -exec rm -rf {} + 2>/dev/null
    rm -f "$tarball"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "$1" in
        status)
            target="$(hip_supported_gpu "${2:?prefix}")" || exit 0
            if hip_runtime_installed; then echo "$target installed"; else echo "$target missing"; fi ;;
        install) hip_runtime_install ;;
        *) echo "usage: rhino-hip.sh status PREFIX | install" >&2; exit 2 ;;
    esac
fi
