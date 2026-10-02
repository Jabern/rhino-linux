# Rhino on Linux

Patches and scripts to get McNeel Rhinoceros running on Linux using Wine and DXVK.

## Quickstart

```bash
git clone https://github.com/Jabern/rhino-linux.git
cd rhino-linux
./install.sh
```

`./install.sh` automatically downloads our pre-built patched Wine runtime (~63 MB) directly from GitHub Releases, so you **do not** need to compile Wine from source.

To run your Rhino installer directly, pass `--installer`:

```bash
./install.sh --installer /path/to/rhino_installer.exe
```

After install, launch it with:

```bash
rhino-9

# or open a model directly:
rhino-9 model.3dm
```

## Dependencies

### Runtime Dependencies
Make sure you have Vulkan drivers and DXVK installed:

- **Arch / Manjaro**:
  ```bash
  sudo pacman -S --needed wine vulkan-icd-loader vulkan-headers dxvk-bin libx11 freetype2 gnutls
  ```
- **Ubuntu / Debian**:
  ```bash
  sudo apt update && sudo apt install -y wine64 libvulkan1 vulkan-tools libx11-6 libfreetype6 libgnutls30 dxvk
  ```
- **Fedora**:
  ```bash
  sudo dnf install -y wine vulkan-loader libX11 freetype gnutls dxvk
  ```
- **openSUSE**:
  ```bash
  sudo zypper install -y wine vulkan libX11 freetype2 libgnutls dxvk
  ```

### Build Dependencies (Optional)
Only required if you choose to compile Wine from source with `--build-wine` (requires `bison`, `flex`, `gcc`, `mingw-w64`, X11 dev headers).

## What the patches do

Stock Wine crashes or has visual glitches with Rhino. These 18 patches fix the main blockers:

1. **OpenMP loops (`vcomp140`)**: Wine lacked 64-bit dynamic loop functions (`_vcomp_for_dynamic_init_i8`/`_next_i8`) and stalled under multi-threaded compute. Patch 01 adds lock-free loop scheduling.
2. **WebView2 & Cloud Zoo (`dcomp`)**: Wine's DirectComposition implementation didn't support visual tree swapchain hosting. Patch 06 lets Edge WebView2 render properly so Cloud Zoo login and web panels don't show blank white boxes.
3. **Menu & toolbar borders (`winex11.drv`)**: Matches 32bpp visual depth and adds alpha blending so context menus and toolbars don't have solid black boxes around them.
4. **Viewport presentation (`XDamage`)**: Presents offscreen DXVK surfaces when the viewport maps, preventing blank/black viewports on startup.
5. **Splash & template screen (`RhinoGreet`)**: Fixes Win64 `GetWindowLongPtr` exports and keeps the startup template window open instead of disappearing behind the main frame.

## Building Wine manually

If you prefer building Wine yourself instead of running `./install.sh`:

```bash
# 1. Clone Wine
git clone https://gitlab.winehq.org/wine/wine.git ~/src/wine
cd ~/src/wine
git checkout wine-11.18

# 2. Apply patches
for p in /path/to/rhino-linux/patches/{0[1-9],1[0-5],1[7-8]}-*.patch; do
    patch -p1 < "$p"
done

# 3. Build Wine 64-bit
mkdir ~/src/build-wine && cd ~/src/build-wine
../wine/configure --enable-win64 --prefix=/opt/wine-rhino --without-capi
make -j$(nproc)

# 4. Configure prefix
cd /path/to/rhino-linux
./tools/deploy-rhino.sh --prefix ~/.wine-rhino --wine /opt/wine-rhino/bin/wine
```

## Credits & Acknowledgements

- Thanks to [ItHasLegs](https://github.com/ItHasLegs/rhino8-wine) for researching the early `uxtheme` dark-mode crash (now upstream in Wine 11.14) and for the `--fresh` wineserver restart concept to clear stale HTTP state for Cloud Zoo OAuth licensing.

## License

- Patches in `patches/` follow Wine's LGPL 2.1+ license.
- Scripts and configs are MIT.
