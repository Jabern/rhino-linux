# Wine Patches for Rhinoceros on Linux

This directory contains 20 modular topic patches for Wine (19 core patches for X11 / XWayland and 1 optional patch for pure Wayland) to run **McNeel Rhinoceros** on Linux with native performance, hardware-accelerated Direct3D 11 viewports, and Cloud Zoo licensing support.

---

## Patch Index

| # | File | Component | Description |
|---|---|---|---|
| **01** | `01-vcomp-dynamic-init-next-i8.patch` | `vcomp140` | Implements lock-free atomic CAS 64-bit dynamic loop scheduling (`_vcomp_for_dynamic_init_i8` and `_vcomp_for_dynamic_next_i8`) in builtin OpenMP. |
| **02** | `02-ntdll-threadpool-worker-leak.patch` | `ntdll` | Rate-limits threadpool worker creation under high-frequency asynchronous work bursts. |
| **03** | `03-set-thread-ideal-processor-ex.patch` | `kernelbase` | Implements `SetThreadIdealProcessorEx` stub required by modern compute runtimes. |
| **04** | `04-wine-x11-layered-and-depth-match.patch` | `winex11.drv` | Matches 32bpp TrueColor visual depth in X11, eliminating black borders around menus and floating toolbars. |
| **05** | `05-wine-menu-alpha-blend.patch` | `win32u` | Supports per-pixel alpha blending on Win32 menus and drop shadows. |
| **06** | `06-wine-dcomp-webview2-visual-hosting.patch` | `dcomp` / `dxgi` | Implements DirectComposition visual tree hosting (`CreateSwapChainForComposition` / `WM_WINE_DCOMP_SET_TARGET`) for Microsoft Edge WebView2 panels and Cloud Zoo. |
| **07** | `07-wine-dcomp-hidden-target-guards.patch` | `dcomp` | Guards against NULL/hidden targets during DirectComposition target teardown. |
| **08** | `08-wine-layered-child-windows.patch` | `win32u` | Maintains backing surfaces for `WS_EX_LAYERED` child windows. |
| **09** | `09-wine-msvcp-throw-cpp-error.patch` | `msvcp140` | Implements `__throw_cpp_error` in MSVCP runtimes. |
| **10** | `10-wine-user32-dialog-dpi-behavior.patch` | `user32` | Standard Win32 Per-Monitor DPI scaling behavior APIs for dialogs and property sheets. |
| **11** | `11-wine-dxgi-unknown-swapchain-format.patch` | `dxgi` | Handles swapchain creation on custom backbuffer pixel formats. |
| **12** | `12-wbemprox-iwbemservices-marshal.patch` | `wbemprox` | Implements `IWbemServices` marshaling for WMI hardware and GPU queries. |
| **13** | `13-wine-services-session0.patch` | `services` | Handles Session 0 process isolation for background licensing services. |
| **14** | `14-wine-comctl32-taskdialog.patch` | `comctl32` | Adds `TaskDialogIndirect` MessageBox compatibility wrapper with distinct button ID mapping. |
| **15** | `15-wine-ncrypt-ecdsa-p256.patch` | `ncrypt` | Implements NCrypt ECDSA P-256 key import for Cloud Zoo TLS token exchange. |
| **16** | `16-winewayland-popups-and-overlays.patch` | `winewayland.drv` | Adds pure Wayland popup and overlay compositing (optional, driver-specific). |
| **17** | `17-rhino-greet-x11-startup.patch` | `winex11.drv` / `win32u` / `server` | Exports unsuffixed Win64 `GetWindowLongPtr`/`SetWindowLongPtr`, enables managed `WS_EX_LAYERED` splash compositing with constant alpha blending, and preserves owned layered window restacking for native `RhinoGreet` fade transitions. |
| **18** | `18-x11-client-surface-repaint.patch` | `winex11.drv` / `win32u` | Presents offscreen DXVK client surfaces on idle window mapping via XDamage and invalidates parent on swapchain recreate. |
| **19** | `19-wine-multimonitor-child-maximize.patch` | `win32u` | Excludes child and MDI windows from monitor-offset calculations when maximized across secondary displays. |
| **20** | `20-wine-xrandr-primary-anchor.patch` | `winex11.drv` | Anchors primary monitor at root (0,0) in XRandR to prevent coordinate shifts and mouse input desync when Wayland compositors dynamically rotate the primary output. |
| **21** | `21-gdiplus-flatten-s-curve-beziers.patch` | `gdiplus` | Fixes Bezier flattening of S-shaped curves (control points on opposite sides of the chord), which were reduced to a straight line; restores curved Grasshopper wires. |

---

## Applying Patches

To apply to an upstream Wine tree (Wine 11.18):

```bash
cd /path/to/wine

# Standard patch series for X11 / XWayland (all except Patch 16):
for p in /path/to/rhino-linux/patches/{0[1-9],1[0-5],1[7-9],2[0-9]}-*.patch; do
    patch -p1 < "$p"
done

# Optional: include pure Wayland driver patch 16
# patch -p1 < /path/to/rhino-linux/patches/16-winewayland-popups-and-overlays.patch
```
