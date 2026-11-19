#!/bin/bash
# make-hip-runtime.sh OUTPUT_DIR: the HIP runtime the amdhip64 bridge uses where the system
# has none (SteamOS, the Flatpak): the libraries of AMD's ROCm packages for Ubuntu 24.04,
# pinned and checked, in rocm-hip-runtime-$ROCM_VERSION-x86_64.tar.xz.
#
#   lib/            libamdhip64, libhsa-runtime64, libamd_comgr, librocprofiler-register
#                   (their RUNPATH is $ORIGIN: they find each other here)
#   lib/fallback/   libnuma and libdrm_amdgpu, which the Flatpak runtime lacks; the bridge
#                   loads them only when the system has none, so Mesa keeps its own
#   licenses/       the packages' copyright files
set -euo pipefail

ROCM_VERSION=6.4.4
ROCM_URL="https://repo.radeon.com/rocm/apt/$ROCM_VERSION"
UBUNTU_URL="http://archive.ubuntu.com/ubuntu"

# url sha256 destination (lib or lib/fallback)
packages=(
    "$ROCM_URL/pool/main/h/hip-runtime-amd/hip-runtime-amd_6.4.43484.60404-129~24.04_amd64.deb eb3523f4d8253f427d1731dfac5c0475442eb6c6952cf0cde8d03c2752e6418e lib"
    "$ROCM_URL/pool/main/h/hsa-rocr/hsa-rocr_1.15.0.60404-129~24.04_amd64.deb 1289b8def423d6717811325e1d8bdcef4211b03f0efc21a5d1db934074b693e2 lib"
    "$ROCM_URL/pool/main/c/comgr/comgr_3.0.0.60404-129~24.04_amd64.deb 673597bcada76ea20d030de9249ee01454228be1c1d33f4944e1132c1101657a lib"
    "$ROCM_URL/pool/main/r/rocprofiler-register/rocprofiler-register_0.4.0.60404-129~24.04_amd64.deb fa39ac3340fc77507c23ee58f42ada12ed53798bf406f4c6ce14c6702f4e01b9 lib"
    "$UBUNTU_URL/pool/main/n/numactl/libnuma1_2.0.18-1ubuntu0.24.04.1_amd64.deb f333b8edf6f0b705c19f2a67008194df66f7aab0fa2350dc98510569a033ff29 lib/fallback"
    "$UBUNTU_URL/pool/main/libd/libdrm/libdrm-amdgpu1_2.4.125-1ubuntu0.1~24.04.2_amd64.deb aa29b7898bae596bf07e55ba178cf8d5ea698fe83688e1b34520d86010251a7a lib/fallback"
)
# the libraries taken from each package's files (others, like libhiprtc, aren't needed)
wanted='libamdhip64\.so|libhsa-runtime64\.so|libamd_comgr\.so|librocprofiler-register\.so|libnuma\.so|libdrm_amdgpu\.so'

out="$(realpath "${1:?usage: make-hip-runtime.sh OUTPUT_DIR}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
name="rocm-hip-runtime-$ROCM_VERSION"
root="$work/$name"
mkdir -p "$root/lib/fallback" "$root/licenses" "$work/debs"

for entry in "${packages[@]}"; do
    read -r url sha dest <<< "$entry"
    deb="$work/debs/$(basename "$url")"
    curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors -o "$deb" "$url"
    echo "$sha  $deb" | sha256sum -c --quiet
    pkg="$(basename "$url" | cut -d_ -f1)"
    mkdir -p "$work/x/$pkg"
    (cd "$work/x/$pkg" && ar x "$deb" && tar -xf data.tar.*)
    # the libraries with their soname links, as the package has them
    find "$work/x/$pkg" \( -type f -o -type l \) -name '*.so.*' | grep -E "/($wanted)" | while read -r lib; do
        cp -a "$lib" "$root/$dest/"
    done
    # Ubuntu's copyright file, or ROCm's LICENSE and NOTICES
    find "$work/x/$pkg" -path '*/doc/*' -type f \( -name copyright -o -iname 'license*' -o -iname 'notices*' \) |
        while read -r file; do mkdir -p "$root/licenses/$pkg"; cp "$file" "$root/licenses/$pkg/"; done
    echo "$pkg $(basename "$url")" >> "$root/PACKAGES"
done

for lib in libamdhip64.so.6 libhsa-runtime64.so.1 libamd_comgr.so.3 librocprofiler-register.so.0 \
           fallback/libnuma.so.1 fallback/libdrm_amdgpu.so.1; do
    [ -e "$root/lib/$lib" ] || { echo "missing $lib" >&2; exit 1; }
done
echo "$ROCM_VERSION" > "$root/VERSION"

# the same bytes wherever it is built, so the checksum tools/rhino-hip.sh pins can be checked
mkdir -p "$out"
tar -C "$work" --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - "$name" |
    xz -9 -T1 > "$out/$name-x86_64.tar.xz"
sha256sum "$out/$name-x86_64.tar.xz"
