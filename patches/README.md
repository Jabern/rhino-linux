# Wine Patches for Rhinoceros on Linux

This directory contains 19 modular topic patches for Wine to run **McNeel Rhinoceros** on Linux with native performance, hardware-accelerated Direct3D 11 viewports, and full Cloud Zoo licensing support.

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
| **10** | `10-wine-user32-dialog-dpi-behavior.patch` | `user32` | Per-Monitor DPI scaling behavior for Win32 dialogs and property sheets. |
| **11** | `11-wine-dxgi-unknown-swapchain-format.patch` | `dxgi` | Handles swapchain creation on custom backbuffer pixel formats. |
| **12** | `12-wbemprox-iwbemservices-marshal.patch` | `wbemprox` | Implements `IWbemServices` marshaling for WMI hardware and GPU queries. |
| **13** | `13-wine-services-session0.patch` | `services` | Handles Session 0 process isolation for background licensing services. |
| **14** | `14-wine-comctl32-taskdialog.patch` | `comctl32` | Adds `TaskDialogIndirect` enhancements for installers and alert sheets. |
| **15** | `15-wine-ncrypt-ecdsa-p256.patch` | `ncrypt` | Implements NCrypt ECDSA P-256 key import for Cloud Zoo TLS token exchange. |
| **16** | `16-winewayland-popups-and-overlays.patch` | `winewayland.drv` | Adds pure Wayland popup and overlay compositing (optional for pure Wayland driver). |
| **17** | `17-rhino-greet-x11-startup.patch` | `winex11.drv` / `ntdll` | Exports unsuffixed Win64 `GetWindowLongPtr`/`SetWindowLongPtr` and preserves owned layered window restacking for `RhinoGreet`. |
| **18** | `18-x11-client-surface-repaint.patch` | `winex11.drv` | Presents offscreen DXVK client surfaces on idle window mapping via XDamage. |
| **19** | `19-wine-multimonitor-child-maximize.patch` | `win32u` | Excludes child and MDI windows from monitor-offset calculations when maximized across secondary displays. |

---

## Applying Patches

To apply to an upstream Wine tree (Wine 11.x):

```bash
cd /path/to/wine
for p in /path/to/rhino-linux/patches/{0[1-9],1[0-5],1[7-9]}-*.patch; do
    patch -p1 < "$p"
done
```
