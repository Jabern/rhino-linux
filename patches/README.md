# Wine Patches for Rhinoceros on Linux

This directory contains 32 modular topic patches for Wine 11.20 (31 core patches for X11 / XWayland and 1 optional patch for pure Wayland) to run **McNeel Rhinoceros** on Linux with native performance, hardware-accelerated Direct3D 11 viewports, and Cloud Zoo licensing support.

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
| **22** | `22-mshtml-show-html-dialog.patch` | `mshtml` / `ieframe` | Implements `ShowHTMLDialog`/`ShowHTMLDialogEx` (HTML dialogs with `dialogArguments`, `returnValue` and `window.close()`) for RhinoScript's `Rhino.HtmlBox`; fixes a missing AddRef in ieframe's `IEnumConnections::Next`. |
| **23** | `23-x11-stretch-last-frame-on-resize.patch` | `winex11.drv` | Prototype: while a child window's GL/Vulkan surface is resized, shows its last frame stretched (like `DXGI_SCALING_STRETCH`) instead of the black the X server fills new areas with. |
| **24** | `24-x11-follow-wm-frame-extents.patch` | `winex11.drv` | Prototype: reads the window manager's `_NET_FRAME_EXTENTS` and matches Wine's caption height to its title bar (runtime only), so maximizing or restoring lays the window out once instead of twice. |
| **25** | `25-x11-offscreen-first-frame.patch` | `winex11.drv` / `win32u` | Prototype: a new or reused offscreen surface is shown only once its first frame has landed (copied on its XDamage event, re-enabled on reuse), instead of copying it straight after `vkQueuePresentKHR` when it still holds black. |
| **26** | `26-x11-restore-frames-on-expose.patch` | `winex11.drv` | Prototype: on `Expose` (e.g. restoring a minimized window), copies every offscreen surface's last frame back at once, at its last on-screen position while the Win32 window is still minimized. |
| **27** | `27-x11-frame-extents-unscaled-only.patch` | `winex11.drv` | Patch 24 only follows the WM's title bar for unscaled (96 DPI) windows: the extents are physical pixels. |
| **28** | `28-x11-wm-class-from-env.patch` | `winex11.drv` | The window class (`WM_CLASS`) comes from `WINE_WM_CLASS` when set, so the taskbar keeps Rhino 7, 8 and 9 apart; all are `Rhino.exe`. |
| **29** | `29-dcomp-dxgi-gpu-composition.patch` | `dcomp` / `dxgi` / `wined3d` | DirectComposition composed on the GPU with D3D11, up to `IDCompositionDevice3`, with windowless composition swap chains; replaces what patches 06 and 07 did, so Edge WebView2 composes on the GPU instead of in software. |
| **30** | `30-cross-process-child-windows.patch` | `win32u` / `winex11.drv` / `server` | Child windows of other processes (WebView2 in Rhino) placed, clipped, updated and shown again as on Windows; the parent doesn't draw over what they draw with a pixel format; window tree in shared memory. |
| **31** | `31-x11-pointer-warps-while-dragging.patch` | `winex11.drv` | Carries on from pointer warps that Xwayland refuses while dragging, so rotating and panning viewports don't spin. |
| **32** | `32-server-refuse-sibling-pid-namespaces.patch` | `server` / `ntdll` | Refuses sharing a wineserver with processes of a sibling PID namespace (another Flatpak instance), whose ids it can't signal. |

---

## Applying Patches

To apply to an upstream Wine tree (Wine 11.20):

```bash
cd /path/to/wine

# Standard patch series for X11 / XWayland (all except Patch 16):
for p in /path/to/rhino-linux/patches/{0[1-9],1[0-5],1[7-9],[2-9][0-9]}-*.patch; do
    patch -p1 < "$p"
done

# Optional: include pure Wayland driver patch 16
# patch -p1 < /path/to/rhino-linux/patches/16-winewayland-popups-and-overlays.patch
```
