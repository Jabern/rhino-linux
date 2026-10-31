# Wine Patches Reference

This repository maintains 35 targeted patches against Wine (tested against Wine 11.20) to run McNeel Rhinoceros 8 and Rhino 9 WIP smoothly on Linux.

Stock Wine encounters several critical blockers when running Rhino: multi-threaded OpenMP crashes, blank Cloud Zoo login windows (due to incomplete DirectComposition visual tree hosting), black borders around toolbars and menus, startup template screen dismissal, viewport rendering glitches upon maximizing, and multi-monitor coordinate bugs.

Below is the technical breakdown of all 35 patches.

---

## Patch Index

| # | Patch | Primary Subsystem | Description |
|---|---|---|---|
| 01 | [`01-vcomp-dynamic-init-next-i8.patch`](../patches/01-vcomp-dynamic-init-next-i8.patch) | `vcomp` / `vcomp140` | 64-bit dynamic OpenMP loop scheduling for multi-threaded math |
| 02 | [`02-ntdll-threadpool-worker-leak.patch`](../patches/02-ntdll-threadpool-worker-leak.patch) | `ntdll` | Thread pool worker caps and idle timeouts to prevent thread exhaustion |
| 03 | [`03-set-thread-ideal-processor-ex.patch`](../patches/03-set-thread-ideal-processor-ex.patch) | `kernelbase` | `SetThreadIdealProcessorEx` stub implementation for .NET CLR affinity |
| 04 | [`04-wine-x11-layered-and-depth-match.patch`](../patches/04-wine-x11-layered-and-depth-match.patch) | `winex11.drv` | 32bpp vs 24bpp depth matching to eliminate solid black boxes around UI |
| 05 | [`05-wine-menu-alpha-blend.patch`](../patches/05-wine-menu-alpha-blend.patch) | `win32u` | 32-bit ARGB alpha blending for popup and menu item bitmaps |
| 06 | [`06-wine-dcomp-webview2-visual-hosting.patch`](../patches/06-wine-dcomp-webview2-visual-hosting.patch) | `dcomp` / `dxgi` | DirectComposition visual tree hosting for Edge WebView2 (Cloud Zoo) |
| 07 | [`07-wine-dcomp-hidden-target-guards.patch`](../patches/07-wine-dcomp-hidden-target-guards.patch) | `dxgi` | Suppress redraws and stale clipping for hidden DComp targets |
| 08 | [`08-wine-layered-child-windows.patch`](../patches/08-wine-layered-child-windows.patch) | `win32u` | Window surface allocation for `WS_EX_LAYERED` child windows |
| 09 | [`09-wine-msvcp-throw-cpp-error.patch`](../patches/09-wine-msvcp-throw-cpp-error.patch) | `msvcp` | Implement `?_Throw_Cpp_error@std@@YAXH@Z` in MSVCP runtimes |
| 10 | [`10-wine-user32-dialog-dpi-behavior.patch`](../patches/10-wine-user32-dialog-dpi-behavior.patch) | `user32` | `SetDialogDpiChangeBehavior` APIs for HiDPI dialog scaling |
| 11 | [`11-wine-dxgi-unknown-swapchain-format.patch`](../patches/11-wine-dxgi-unknown-swapchain-format.patch) | `dxgi` | Graceful fallback for `DXGI_FORMAT_UNKNOWN` backbuffer formats |
| 12 | [`12-wbemprox-iwbemservices-marshal.patch`](../patches/12-wbemprox-iwbemservices-marshal.patch) | `wbemprox` | Free-threaded marshaler (`IMarshal`) support for WMI queries |
| 13 | [`13-wine-services-session0.patch`](../patches/13-wine-services-session0.patch) | `server` / `services` | Isolate `services.exe` in Session 0 namespace for licensing RPC |
| 14 | [`14-wine-comctl32-taskdialog.patch`](../patches/14-wine-comctl32-taskdialog.patch) | `comctl32` | `TaskDialog` and `TaskDialogIndirect` dialog implementations |
| 15 | [`15-wine-ncrypt-ecdsa-p256.patch`](../patches/15-wine-ncrypt-ecdsa-p256.patch) | `ncrypt` | ECDSA P-256 key import and signature support for Cloud Zoo JWTs |
| 16 | [`16-winewayland-popups-and-overlays.patch`](../patches/16-winewayland-popups-and-overlays.patch) | `winewayland.drv` | Popup role management and client overlap compositing for Wayland |
| 17 | [`17-rhino-greet-x11-startup.patch`](../patches/17-rhino-greet-x11-startup.patch) | `user32` / `win32u` | Fix `GetWindowLongPtr` exports and keep `RhinoGreet` splash visible |
| 18 | [`18-x11-client-surface-repaint.patch`](../patches/18-x11-client-surface-repaint.patch) | `win32u` / `winex11` | Invalidate and repaint on Vulkan swapchain recreate (eliminates black bars) |
| 19 | [`19-wine-multimonitor-child-maximize.patch`](../patches/19-wine-multimonitor-child-maximize.patch) | `win32u` | Prevent MDI child viewports from shifting off-screen on multi-monitors |
| 20 | [`20-wine-xrandr-primary-anchor.patch`](../patches/20-wine-xrandr-primary-anchor.patch) | `winex11.drv` | Anchor primary display at `(0, 0)` under XRandR for Wayland bridges |
| 21 | [`21-gdiplus-flatten-s-curve-beziers.patch`](../patches/21-gdiplus-flatten-s-curve-beziers.patch) | `gdiplus` | Correct flattening of S-shaped Bezier curves (curved Grasshopper wires) |
| 22 | [`22-mshtml-show-html-dialog.patch`](../patches/22-mshtml-show-html-dialog.patch) | `mshtml` / `ieframe` | HTML dialogs (`ShowHTMLDialogEx`) for RhinoScript's `Rhino.HtmlBox` |
| 23 | [`23-x11-stretch-last-frame-on-resize.patch`](../patches/23-x11-stretch-last-frame-on-resize.patch) | `winex11.drv` | Show a resized viewport's last frame stretched instead of black |
| 24 | [`24-x11-follow-wm-frame-extents.patch`](../patches/24-x11-follow-wm-frame-extents.patch) | `winex11.drv` | Match Wine's caption height to the WM's title bar: one layout per maximize/restore |
| 25 | [`25-x11-offscreen-first-frame.patch`](../patches/25-x11-offscreen-first-frame.patch) | `winex11.drv` / `win32u` | Show new or reused offscreen surfaces only once their first frame has landed |
| 26 | [`26-x11-restore-frames-on-expose.patch`](../patches/26-x11-restore-frames-on-expose.patch) | `winex11.drv` | Put offscreen frames back at once when a window is exposed (e.g. restored) |
| 27 | [`27-x11-frame-extents-unscaled-only.patch`](../patches/27-x11-frame-extents-unscaled-only.patch) | `winex11.drv` | Follow the WM's title bar only for unscaled windows |
| 28 | [`28-x11-wm-class-from-env.patch`](../patches/28-x11-wm-class-from-env.patch) | `winex11.drv` | Window class from `WINE_WM_CLASS`, one taskbar entry per Rhino version |

---

## Detailed Patch Breakdown

### Patch 01: 64-bit OpenMP Dynamic Loop Scheduling
- **File**: [`patches/01-vcomp-dynamic-init-next-i8.patch`](../patches/01-vcomp-dynamic-init-next-i8.patch)
- **Subsystem**: `dlls/vcomp/main.c`, `dlls/vcomp/vcomp.spec`, `dlls/vcomp140/vcomp140.spec`
- **Problem**: Rhino and its geometry kernels (OpenNURBS, mesh booleans, raytraced intersection solvers) rely on Microsoft Visual C++ OpenMP (`vcomp140.dll`) to parallelize heavy numerical work across CPU cores. Stock Wine only implemented 32-bit dynamic loop iteration functions (`_vcomp_for_dynamic_init`, `_vcomp_for_dynamic_next`), leaving 64-bit integer loop iterations (`_vcomp_for_dynamic_init_i8`, `_vcomp_for_dynamic_next_i8`) as stubs. When multi-threaded geometry operations trigger large 64-bit iteration loops, Rhino either stalls, crashes, or hangs on all worker threads.
- **Solution**: Implements lock-free 64-bit loop initialization and chunk acquisition using sequence locks (`ULONG64 dynamic_begin`, `dynamic_end`).

---

### Patch 02: NT Threadpool Worker Leak Cap
- **File**: [`patches/02-ntdll-threadpool-worker-leak.patch`](../patches/02-ntdll-threadpool-worker-leak.patch)
- **Subsystem**: `dlls/ntdll/threadpool.c`
- **Problem**: Under sustained computing loads (e.g. Grasshopper solution solves, background mesh generation, display pipeline caching), asynchronous I/O and worker items queued to the Windows Threadpool caused Wine's `ntdll` implementation to spawn unbounded worker threads without timely reaping. Over extended modeling sessions, worker thread counts could exceed several hundred, exhausting system file descriptors and thread handles.
- **Solution**: Introduces thread pool worker caps (`MAX_POOL_WORKERS = 64`, `MAX_GLOBAL_WORKERS = 256`) and enforces strict idle timeouts (`THREADPOOL_WORKER_TIMEOUT = 5000 ms`) to prevent thread leakage.

---

### Patch 03: `SetThreadIdealProcessorEx` Implementation
- **File**: [`patches/03-set-thread-ideal-processor-ex.patch`](../patches/03-set-thread-ideal-processor-ex.patch)
- **Subsystem**: `dlls/kernelbase/thread.c`
- **Problem**: Modern .NET runtimes (used by Rhino 8 and 9) and multi-threaded geometry plugins invoke `SetThreadIdealProcessorEx` to bind thread affinities across processor groups and NUMA nodes. In stock Wine, this function returned `ERROR_CALL_NOT_IMPLEMENTED`, producing verbose warnings in terminal logs and sub-optimal thread scheduling across heterogeneous CPU cores (such as Intel P/E-cores).
- **Solution**: Implements `SetThreadIdealProcessorEx` in `kernelbase.dll` by querying and setting the processor number via `NtQueryInformationThread` / `NtSetInformationThread`.

---

### Patch 04: X11 Depth Matching & Layered Window Alpha Surfaces
- **File**: [`patches/04-wine-x11-layered-and-depth-match.patch`](../patches/04-wine-x11-layered-and-depth-match.patch)
- **Subsystem**: `dlls/winex11.drv/bitblt.c`, `dlls/winex11.drv/init.c`, `dlls/winex11.drv/window.c`
- **Problem**: Rhino utilizes 32bpp ARGB visual surfaces for modern floating tool palettes, command bar popups, and translucent overlay elements. When performing `StretchBlt` or blitting between drawables with mismatched color depths (e.g. 32bpp source vs 24bpp root window), `XCopyArea` fails or produces solid black bounding boxes around translucent UI elements.
- **Solution**: Validates drawable geometry depths prior to hardware blits; falls back to GDI software stretching when depths differ, and properly handles layered window alpha blending under X11.

---

### Patch 05: 32-bit ARGB Menu Bitmap Alpha Blending
- **File**: [`patches/05-wine-menu-alpha-blend.patch`](../patches/05-wine-menu-alpha-blend.patch)
- **Subsystem**: `dlls/win32u/menu.c`
- **Problem**: Modern Rhino toolbars and right-click context menus use 32-bit bitmaps with alpha channels for tool icons. Stock Wine's menu rendering drew bitmaps using opaque RGB blits, turning the transparent margins around circular or irregularly shaped icons into solid black squares.
- **Solution**: Scans 32bpp menu bitmaps for non-zero alpha pixels; if an alpha channel is present, uses `alpha_blend` with `AC_SRC_OVER` instead of opaque raster operations.

---

### Patch 06: DirectComposition WebView2 Visual Tree Hosting
- **File**: [`patches/06-wine-dcomp-webview2-visual-hosting.patch`](../patches/06-wine-dcomp-webview2-visual-hosting.patch)
- **Subsystem**: `dlls/dcomp/device.c`, `dlls/dxgi/device.c`, `dlls/dxgi/factory.c`, `dlls/dxgi/swapchain.c`
- **Problem**: Rhino 8 and 9 embed Microsoft Edge WebView2 for Cloud Zoo authentication (logging into your McNeel account), the Rhino Package Manager (`PackageManager`), and HTML-based panels. WebView2 relies on DirectComposition (`dcomp.dll`) to host DXGI swapchain visuals in a composite visual tree. Stock Wine lacked visual tree swapchain association, leaving WebView2 windows blank, white, or completely transparent.
- **Solution**: Adds DirectComposition visual tree swapchain hosting, allowing DXGI swapchains created by WebView2 to attach directly to composition visual targets and composite into the host window.

---

### Patch 07: DirectComposition Hidden Target Guards
- **File**: [`patches/07-wine-dcomp-hidden-target-guards.patch`](../patches/07-wine-dcomp-hidden-target-guards.patch)
- **Subsystem**: `dlls/dxgi/factory.c`
- **Problem**: DirectComposition targets can be hidden by design (e.g. when an inspector tab is docked behind another or minimized). Stock Wine continued to trigger periodic re-blits and updates to hidden targets, consuming unnecessary GPU/CPU cycles and causing stale DC clipping artifacts.
- **Solution**: Verifies that DComp target ancestor windows are actually visible before executing composition re-blits, preventing stale draw calls and unnecessary background wakeups.

---

### Patch 08: Layered Child Window Surfaces
- **File**: [`patches/08-wine-layered-child-windows.patch`](../patches/08-wine-layered-child-windows.patch)
- **Subsystem**: `dlls/win32u/window.c`
- **Problem**: Rhino embeds child controls with the `WS_EX_LAYERED` extended window style inside dockable tool panels and viewport overlays. Stock Wine explicitly disallowed creating window surfaces for child windows (`is_child`), resulting in dockable panels failing to render or disappearing behind parent containers.
- **Solution**: Permits window surface allocation for child windows when `WS_EX_LAYERED` is set: `else if (is_child && !(ex_style & WS_EX_LAYERED)) needs_surface = FALSE;`.

---

### Patch 09: MSVCP `_Throw_Cpp_error` Exports
- **File**: [`patches/09-wine-msvcp-throw-cpp-error.patch`](../patches/09-wine-msvcp-throw-cpp-error.patch)
- **Subsystem**: `dlls/msvcp110/msvcp110.spec`, `dlls/msvcp120/msvcp120.spec`, `dlls/msvcp140/msvcp140.spec`, `dlls/msvcp90/exception.c`
- **Problem**: Third-party CAD plugins and Rhino C++ geometry libraries built against MSVC rely on `?_Throw_Cpp_error@std@@YAXH@Z` when raising standard C++ concurrency and thread errors (`std::future_error`, `std::system_error`). In stock Wine, this symbol was marked as an unimplemented stub, crashing the application when an error was thrown.
- **Solution**: Implements and exports `_Throw_Cpp_error` across MSVCP 110, 120, and 140 runtimes.

---

### Patch 10: Dialog DPI Change Behavior APIs
- **File**: [`patches/10-wine-user32-dialog-dpi-behavior.patch`](../patches/10-wine-user32-dialog-dpi-behavior.patch)
- **Subsystem**: `dlls/user32/dialog.c`, `dlls/user32/user32.spec`, `include/winuser.h`, `include/windef.h`
- **Problem**: Rhino's options, document properties, and print dialogs utilize Windows 10+ Per-Monitor DPI v2 APIs (`SetDialogDpiChangeBehavior`, `GetDialogDpiChangeBehavior`, `SetDialogControlDpiChangeBehavior`, `GetDialogControlDpiChangeBehavior`) to query and adjust dialog layout scaling across displays of differing pixel densities. In stock Wine, these functions were absent, leading to dialog creation failures or misaligned fonts on multi-DPI displays.
- **Solution**: Implements `SetDialogDpiChangeBehavior`, `GetDialogDpiChangeBehavior`, `SetDialogControlDpiChangeBehavior`, and `GetDialogControlDpiChangeBehavior` in `user32.dll` matching official Windows API signatures and property bitmask semantics.

---

### Patch 11: DXGI Unknown Swapchain Format Fallback
- **File**: [`patches/11-wine-dxgi-unknown-swapchain-format.patch`](../patches/11-wine-dxgi-unknown-swapchain-format.patch)
- **Subsystem**: `dlls/dxgi/utils.c`
- **Problem**: Certain display pipeline components and third-party viewport plugins pass `DXGI_FORMAT_UNKNOWN` in their swapchain description, expecting the DXGI runtime to select the desktop default format (`B8G8R8A8_UNORM`). Stock Wine rejected this outright, failing swapchain initialization.
- **Solution**: Translates `DXGI_FORMAT_UNKNOWN` to `WINED3DFMT_B8G8R8A8_UNORM` in `wined3d_swapchain_desc_from_dxgi` to maintain compatibility with legacy renderers.

---

### Patch 12: `IWbemServices` Free-Threaded Marshaling
- **File**: [`patches/12-wbemprox-iwbemservices-marshal.patch`](../patches/12-wbemprox-iwbemservices-marshal.patch)
- **Subsystem**: `dlls/wbemprox/services.c`
- **Problem**: Rhino's license validation and hardware diagnostics query system information via Windows Management Instrumentation (WMI / `wbemprox`). When WMI queries are initiated across multi-threaded COM apartments, stock Wine's `IWbemServices` failed `QueryInterface` for `IID_IMarshal`, causing WMI queries to fail with `E_NOINTERFACE`.
- **Solution**: Aggregates a free-threaded marshaler (`CoCreateFreeThreadedMarshaler`) into `IWbemServices`, permitting thread-safe cross-apartment WMI calls.

---

### Patch 13: `services.exe` Session 0 Isolation
- **File**: [`patches/13-wine-services-session0.patch`](../patches/13-wine-services-session0.patch)
- **Subsystem**: `server/mapping.c`, `programs/services/rpc.c`, `programs/services/services.c`
- **Problem**: Background licensing services (such as the McNeel Update Service or LAN Zoo license manager) run as Windows services and communicate with Rhino via RPC/named pipes. In stock Wine, service processes were not segregated into the Session 0 namespace, creating security and pipe path desyncs with desktop client processes.
- **Solution**: Detects `services.exe` and ensures service RPC listeners and namespace mappings conform to Windows Session 0 conventions.

---

### Patch 14: Common Controls `TaskDialog` Support
- **File**: [`patches/14-wine-comctl32-taskdialog.patch`](../patches/14-wine-comctl32-taskdialog.patch)
- **Subsystem**: `dlls/comctl32/Makefile.in`, `dlls/comctl32/comctl32.spec`, `dlls/comctl32/taskdialog.c`
- **Problem**: Rhino 8 and 9 use native Windows Task Dialogs (`TaskDialog`, `TaskDialogIndirect`) for critical prompts, license expiration alerts, and crash reporting. In stock Wine, `comctl32.dll` lacked complete task dialog implementations, causing alerts to crash or drop silently.
- **Solution**: Adds full `TaskDialog` and `TaskDialogIndirect` window implementations in `comctl32.dll`.

---

### Patch 15: `ncrypt` ECDSA P-256 Support for Cloud Zoo
- **File**: [`patches/15-wine-ncrypt-ecdsa-p256.patch`](../patches/15-wine-ncrypt-ecdsa-p256.patch)
- **Subsystem**: `dlls/ncrypt/main.c`
- **Problem**: Rhino Cloud Zoo licensing uses Elliptic Curve Digital Signature Algorithm (ECDSA P-256) JSON Web Tokens (JWTs) to authenticate user licenses against McNeel servers. Stock Wine's `ncrypt.dll` lacked support for creating, importing, and verifying ECDSA P-256 keys (`BCRYPT_ECDSA_PUBLIC_P256_MAGIC` / `BCRYPT_ECDSA_PRIVATE_P256_MAGIC`), resulting in failed login handshakes.
- **Solution**: Adds ECDSA P-256 algorithm key object initialization and key blob import routines to `ncrypt.dll`.

---

### Patch 16: Wayland Popups and Overlays
- **File**: [`patches/16-winewayland-popups-and-overlays.patch`](../patches/16-winewayland-popups-and-overlays.patch)
- **Subsystem**: `dlls/winewayland.drv/wayland_surface.c`, `dlls/winewayland.drv/waylanddrv.h`, `dlls/winewayland.drv/window.c`
- **Problem**: When running Wine with the native Wayland driver (`winewayland.drv`), CAD overlays (such as the Rhino Gumball manipulator, cursor coordinate HUD, and popup menus) conflict with Wayland subsurfaces and popup roles. Sibling windows positioned above client surfaces in z-order were improperly clipped or obscured.
- **Solution**: Reconstructs overlapping sibling window rectangles (`update_client_overlaps`) and composites them above client surfaces under Wayland.

---

### Patch 17: `RhinoGreet` Splash & Startup Window Visibility
- **File**: [`patches/17-rhino-greet-x11-startup.patch`](../patches/17-rhino-greet-x11-startup.patch)
- **Subsystem**: `dlls/user32/user32.spec`, `dlls/win32u/window.c`, `dlls/winex11.drv/init.c`
- **Problem**: Rhino presents a startup splash and template chooser window (`RhinoGreet`). In 64-bit Wine, `user32.dll` lacked entry point aliases for `GetWindowLongPtr` and `SetWindowLongPtr` (standard Windows exports both non-suffixed and `A`/`W` variants). Furthermore, changing window ownership did not notify the X11 driver to re-evaluate window stacking, causing `RhinoGreet` to disappear or slip behind the main workstation window on launch.
- **Solution**: Adds 64-bit entry point aliases for `GetWindowLongPtr` and `SetWindowLongPtr`, and triggers `update_window_state` on owner changes in `set_window_owner`.

---

### Patch 18: Vulkan Swapchain Repaint & Client Surface Rebind
- **File**: [`patches/18-x11-client-surface-repaint.patch`](../patches/18-x11-client-surface-repaint.patch)
- **Subsystem**: `include/wine/gdi_driver.h`, `dlls/win32u/window.c`, `dlls/win32u/vulkan.c`, `dlls/winex11.drv/init.c`
- **Problem**: When maximizing a viewport inside an unmaximized Rhino window, the backing X11 window geometry changes, triggering `VK_ERROR_OUT_OF_DATE_KHR` in the Vulkan presenter. DXVK catches this error and recreates the swapchain to the new dimensions ($1595 \times 802$). However, Rhino's `WM_SIZE` dispatch completed before swapchain recreation finished. Because Rhino only repaints on demand, the viewport sat with an unrendered black bar in the resized area until the user physically moved the mouse.
- **Solution**: 
  1. Rebinds source drawable DC rectangles on X11 client surface updates (`init.c`).
  2. In `win32u_vkCreateSwapchainKHR`, when recreating an existing swapchain (`create_info->oldSwapchain`), immediately invalidates the parent MDI frame and viewport client window via `NtUserRedrawWindow(..., RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN)`.
  3. In `win32u_vkQueuePresentKHR`, immediately invalidates the surface when `VK_ERROR_OUT_OF_DATE_KHR` occurs.
  4. This ensures that as soon as DXVK finishes recreating the swapchain, Wine dispatches `WM_PAINT` to the viewport, eliminating the black bar instantly without requiring mouse movement.

---

### Patch 19: Multi-Monitor MDI Child Maximize Bounds
- **File**: [`patches/19-wine-multimonitor-child-maximize.patch`](../patches/19-wine-multimonitor-child-maximize.patch)
- **Subsystem**: `dlls/win32u/window.c`
- **Problem**: When Rhino runs on a secondary display in a multi-monitor setup, double-clicking a viewport tab to maximize it caused the viewport to disappear into pitch-black space. Wine's `get_maximized_rect` and `get_min_max_info` functions unconditionally applied the secondary monitor's desktop coordinates (`rcWork`) even to child windows (`WS_CHILD`). Because an MDI child viewport's coordinates are relative to its parent MDIClient window (not desktop root), applying monitor coordinates threw the viewport thousands of pixels off-screen.
- **Solution**: Explicitly excludes child windows (`!(style & WS_CHILD)`) from desktop monitor-offset bounds calculations in `get_maximized_rect` and `get_min_max_info`.

---

### Patch 20: XRandR Primary Monitor Anchor for Wayland Compositors
- **File**: [`patches/20-wine-xrandr-primary-anchor.patch`](../patches/20-wine-xrandr-primary-anchor.patch)
- **Subsystem**: `dlls/winex11.drv/xrandr.c`
- **Problem**: When running under Wayland window managers (such as Niri or Hyprland via `xwayland-satellite`), moving focus or windows across monitors causes the compositor to dynamically switch which output is designated as the XRandR primary display. In stock Wine, changing the primary display shifted Wine's virtual desktop origin `(0, 0)`. When this occurred, existing Rhino windows and mouse cursor coordinates desynced by a full monitor width (e.g. 1920 pixels), freezing mouse interaction.
- **Solution**: Anchors the primary display rectangle to root `(0, 0)` in `get_primary_rect`, keeping coordinate mapping completely stable across dynamic monitor events.

### Patch 21: GDI+ Flattening of S-Shaped Bezier Curves
- **File**: [`patches/21-gdiplus-flatten-s-curve-beziers.patch`](../patches/21-gdiplus-flatten-s-curve-beziers.patch)
- **Subsystem**: `dlls/gdiplus/graphicspath.c`
- **Reported by**: [eqeka](https://github.com/eqeka), who found that Grasshopper wires were drawn straight.
- **Problem**: Grasshopper draws every wire as a single cubic Bezier (`GraphicsPath.AddBezier`) stroked with a wide pen, which GDI+ flattens into line segments first. Wine's `flatten_bezier` judged flatness only by the distance of the curve's middle point from the chord. For a point-symmetric S-curve, which is exactly what Grasshopper's wires are, that middle point lies on the chord, so the whole curve was accepted as flat and drawn as one straight line. Unpatched upstream Wine (11.18, 11.19 and master) behaves the same way.
- **Solution**: When the two control points lie on opposite sides of the chord, the segment is only accepted once both control points are also within tolerance, so S-curves are subdivided until each half is C-shaped. C-shaped curves (arcs, ellipses, rounded rectangles) keep the original criterion and flatten exactly as before.

### Patch 22: HTML Dialogs for RhinoScript's HtmlBox
- **File**: [`patches/22-mshtml-show-html-dialog.patch`](../patches/22-mshtml-show-html-dialog.patch)
- **Subsystem**: `dlls/mshtml/htmldlg.c` (new), `dlls/mshtml/htmlwindow.c`, `dlls/mshtml/oleobj.c`, `dlls/ieframe/events.c`
- **Problem**: `Rhino.HtmlBox` loads `mshtml.dll` and calls `ShowHTMLDialogEx`, which Wine doesn't export (`ShowHTMLDialog` was a stub returning `E_NOTIMPL`). RhinoScript then returns `Null` without showing anything. Installing Internet Explorer with winetricks doesn't help 64-bit Rhino.
- **Solution**: `ShowHTMLDialogEx` hosts Wine's WebBrowser control in a dialog frame sized from the options string (`dialogWidth`, `dialogHeight`, `dialogLeft`, `dialogTop`, `center`, `resizable`, `scroll`), with a modal loop or modeless mode. The dialog's top-level window exposes `dialogArguments` and `returnValue`, readable from inline scripts, and `window.close()` closes the dialog. `ShowHTMLDialog` now forwards to it.
  ieframe's `IEnumConnections::Next` returned sinks without AddRef, so mshtml's `window.close()` path released every `DWebBrowserEvents2` sink once too often; it now AddRefs as COM requires.
- **Needs**: the 64-bit Wine Gecko in the prefix, which `deploy-rhino.sh` now installs (wineboot only installs the 32-bit one).
- **Follows McNeel's `Rhino.HtmlBox` documentation**: a size without a unit is in em (as in IE 5 and later), `dialogHeight` is at least 100 px, and without `dialogWidth`/`dialogHeight` the dialog takes its size from the page's root element (`<HTML style="width: 22em; height: 12em">`, as in McNeel's example) before it is shown. `window.dialogWidth`, `dialogHeight`, `dialogLeft` and `dialogTop` read and change the dialog's geometry, and `unadorned:yes` gives a dialog without a frame.

### Patches 23-27: No Black Flashes When Windows Change State
- **Files**: [`23`](../patches/23-x11-stretch-last-frame-on-resize.patch), [`24`](../patches/24-x11-follow-wm-frame-extents.patch), [`25`](../patches/25-x11-offscreen-first-frame.patch), [`26`](../patches/26-x11-restore-frames-on-expose.patch), [`27`](../patches/27-x11-frame-extents-unscaled-only.patch)
- **Problem**: Rhino's viewports and WPF panels are child windows, which Wine renders offscreen and copies into the main window. When the window was resized, maximized or restored, the X server filled the new or exposed areas with black until Rhino had presented new frames; a maximize also laid everything out twice, because Wine placed the client area below its own 26 px caption while the window manager drew a 28 px title bar.
- **Solution**: resized surfaces show their last frame stretched (23); Wine reads `_NET_FRAME_EXTENTS` and matches its caption height to the window manager's title bar, for unscaled windows (24, 27); a new or reused surface is only shown once its first frame has landed, copied on its XDamage event (25); and on `Expose` every surface's last frame is put back at once (26).
- **Measured** (Rhino 8, KDE Wayland): restoring a minimized window went from ~510 ms of black to ~25 ms. Rhino 9 on Cinnamon: restore 370 ms -> 0 ms; maximize 1523 ms -> 750 ms, the rest being Rhino rebuilding each WPF panel's swap chain.

### Patch 28: One Taskbar Entry per Rhino Version
- **File**: [`28-x11-wm-class-from-env.patch`](../patches/28-x11-wm-class-from-env.patch)
- **Problem**: Wine names every window's X11 class after the program, and Rhino 7, 8 and 9 are all `Rhino.exe`. Taskbars match windows to menu entries by that class, so Cinnamon and KDE grouped the three versions under one button and one icon.
- **Solution**: when `WINE_WM_CLASS` is set, Wine uses it as the window class instead. `rhino-linux` sets `rhino7`, `rhino8` or `rhino9`, and each version's menu entry has the matching `StartupWMClass` and the icon of its own `Rhino.exe`, as on Windows. Without the variable nothing changes.

### Patch 29: DirectComposition Composed on the GPU
- **File**: [`29-dcomp-dxgi-gpu-composition.patch`](../patches/29-dcomp-dxgi-gpu-composition.patch)
- **Subsystem**: `dlls/dcomp`, `dlls/dxgi` (`composition.c`, new), `dlls/wined3d`, `include/dcomp.idl`
- **Problem**: Edge WebView2 (Chromium 116), which draws Rhino 8's Script Editor and Rhino 9's panels, only uses DirectComposition when `IDCompositionDevice3` exists, and otherwise falls back to slow software compositing. Patches 06 and 07 copied every frame from the GPU into a DIB and drew it with GDI, through hidden windows and subclassing.
- **Solution**: replaces what 06 and 07 did. `CreateSwapChainForComposition` creates a windowless swap chain of D3D11 textures; dcomp implements devices up to `IDCompositionDevice3`, visuals, surfaces and virtual surfaces, transforms, clips, effect groups and animations, with pending state frozen by `Commit`. The compositor draws each target's committed visual tree into a swap chain of the target window with D3D11, one textured quad per visual, and composes again on each present. Frames survive `ResizeBuffers` until the next present.

### Patch 30: Child Windows of Other Processes
- **File**: [`30-cross-process-child-windows.patch`](../patches/30-cross-process-child-windows.patch)
- **Subsystem**: `dlls/win32u`, `dlls/winex11.drv`, `server/window.c`, `server/protocol.def`
- **Problem**: WebView2 places its windows, from Edge's own processes, inside Rhino's windows. Wine didn't tell those windows when an ancestor in Rhino moved, resized or was shown, didn't clip them to their ancestors, and let Rhino's window draw over them: Script Editor panels turned grey when switching tabs and black while resizing. Rhino also asked the wineserver 41000 times a second for parents and siblings of those windows.
- **Solution**: child X windows are placed from the server's visible rects and clipped to their ancestors; windows of other processes below a window that moves or is shown get `WM_WINE_UPDATEWINDOWSTATE` and show their last frame again where they now are, and so does the toplevel when they move; what the descendants of a transparent window (a WPF `HwndHost`) draw with a pixel format is left out of the parent's visible region and window surface, so the parent's Vulkan swap chain is clipped around it; client windows keep their last frame when they change between direct and redirected; and the window tree is published in shared memory, as on Windows.

### Patch 31: Rotating and Panning When Pointer Warps Are Refused
- **File**: [`31-x11-pointer-warps-while-dragging.patch`](../patches/31-x11-pointer-warps-while-dragging.patch)
- **Subsystem**: `dlls/winex11.drv/mouse.c`
- **Problem**: Rhino warps the cursor to the other side of a viewport when it leaves it while rotating or panning. Xwayland refuses such warps, so every following event looked like a jump across the viewport and the view spun wildly.
- **Solution**: when the first position after a warp during a drag shows it was refused, positions are reported moved by what the warp would have moved them, until the buttons are released, as `SetCursorPos` always moves the cursor on Windows.

### Patch 32: One wineserver per PID Namespace
- **File**: [`32-server-refuse-sibling-pid-namespaces.patch`](../patches/32-server-refuse-sibling-pid-namespaces.patch)
- **Subsystem**: `server/request.c`, `dlls/ntdll/unix/server.c`
- **Problem**: the wineserver signals and suspends its processes by their Unix ids. A process in a sibling PID namespace, like one in another Flatpak instance of the app, reports ids that mean nothing or another process there: Wine processes outlived their server and threads could be suspended by mistake.
- **Solution**: the server refuses such connections, the client stops with an explanation, and `wineserver -k` says why it can't signal a server it can't see.

### Patch 33: Menus and Popups Show Their First Frame
- **File**: [`33-x11-frame-landed-per-surface.patch`](../patches/33-x11-frame-landed-per-surface.patch)
- **Subsystem**: `dlls/winex11.drv/init.c`, `dlls/winex11.drv/opengl.c`, `dlls/win32u/vulkan.c`, `include/wine/gdi_driver.h`
- **Problem**: WPF menus and popups, like the Options menu of Rhino 9's sign-in window, came up black, and only the items under the pointer appeared. They create a swap chain at a small size and another at their final one. Wine took any damage event of the window as a frame landing in all its surfaces, and resizing the old surface's X window along with the window damaged it too: its empty content was shown over the new frame.
- **Solution**: the client surface notes when the application presents, before the driver can hear about the frame, and forgets it when resized or reused; a damage event counts as a landed frame only for the surface whose window it is for, once the application has presented to it.

### Patch 34: Antialiasing in OpenGL Viewports
- **File**: [`34-x11-egl-alpha-window-formats.patch`](../patches/34-x11-egl-alpha-window-formats.patch)
- **Subsystem**: `dlls/winex11.drv/opengl.c`, `dlls/win32u/opengl.c`
- **Problem**: with EGL, Wine 11's default OpenGL backend on X11, NVIDIA only offers configs with an alpha channel on a 32-bit visual, and Wine doesn't let windows of another depth than the screen's draw with OpenGL, so no window format had alpha. Rhino's OpenGL pipeline looks for one to list their antialiasing modes: the list stayed empty, and after showing a layout with a detail, Rhino turned multisampling off for good, leaving every viewport jagged until a restart. Other applications (SDL, OpenTK) found no format at all.
- **Solution**: windows of these formats are created with a config of the screen depth and the same color sizes, and Wine renders into a framebuffer of the requested format (alpha, samples, depth, stencil), which it copies to the window. A framebuffer resized while the application draws now presents that frame first, instead of an empty one.

### Patch 35: Viewports at the Monitor's Refresh Rate on Wayland
- **File**: [`35-x11-offscreen-surfaces-toplevel-pacing.patch`](../patches/35-x11-offscreen-surfaces-toplevel-pacing.patch)
- **Subsystem**: `dlls/winex11.drv/window.c`, `dlls/winex11.drv/init.c`, `dlls/winex11.drv/event.c`
- **Problem**: GL and Vulkan child windows render into offscreen X windows that Wine kept in a hidden "dummy parent". Xwayland paces presents with the frame callbacks of a window's top-level window, and presents to a window without one with a 17 ms timer, so vsync ran at about 60 Hz whatever the monitor: Rhino's viewports ran at 59 fps on a 144 Hz display (147 fps on Windows on the same laptop).
- **Solution**: offscreen client windows live in an invisible, input-transparent window inside their own top-level window, which follows the top-level when Wine recreates its X window. Unmapping the top-level (minimizing) discards their contents, so the last frame of each surface is kept in a pixmap and shown again on restore until the application presents a new one. Rhino 8 viewports: 59 fps to 137-149 fps with vsync.

### Patch 36: Font Files Opened Once, Not Fifty Times
- **File**: [`36-dwrite-keep-recent-font-streams.patch`](../patches/36-dwrite-keep-recent-font-streams.patch)
- **Subsystem**: `dlls/dwrite/font.c`
- **Problem**: DirectWrite's loader for local font files dropped a file's mapping as soon as its last stream was released. Building the system font collection asks for the same file's stream many times in a row, so while Rhino 8 started, its UI thread opened, mapped, unmapped and closed each of the system's 871 font files about fifty times: 43,000 opens, each several wineserver requests, about 3 s before Rhino could start its .NET code. Windows opens 5,370 files in its whole startup.
- **Solution**: the loader holds a reference to the 32 streams it handed out last, so a file asked for again stays mapped. Font file opens while Rhino starts: 43,300 to 4,180; time to ready 12.6 s to 9.9 s. The font collection itself is unchanged (324 families and 2,064 faces on the test machine, before and after).

### Patch 37: No Stall on Cloud Metadata Checks
- **File**: [`37-ws2_32-linklocal-unreachable.patch`](../patches/37-ws2_32-linklocal-unreachable.patch)
- **Subsystem**: `dlls/ws2_32/socket.c`
- **Problem**: Rhino 8 checks whether it runs on an AWS EC2 machine (for AWS Marketplace licensing) by asking `http://169.254.169.254/latest/api/token`, synchronously on its UI thread. Link-local addresses are never forwarded by a router, but without an on-link route Linux sends them to the default gateway (or a VPN), which drops them, and the connection waits until Rhino's 3-second timeout: every Rhino thread sat idle for 3.0 s.
- **Solution**: with `WINE_LINKLOCAL_UNREACHABLE=1`, `connect()` and `ConnectEx()` fail link-local IPv4 destinations (IPv4-mapped ones too, as .NET uses) at once with `WSAEHOSTUNREACH`, which is what Rhino gets on a network where the address isn't there. Wine leaves it off by default; `rhino-linux` turns it on unless the machine's firmware names a cloud provider (Amazon EC2, Google, Azure, OpenStack, Oracle, Alibaba, DigitalOcean, Hetzner), where the metadata service answers. Time to ready 9.9 s to 6.8 s.

### Patch 38: Module Lookups on the Own Process Without Server Round Trips
- **File**: [`38-kernelbase-own-process-modules.patch`](../patches/38-kernelbase-own-process-modules.patch)
- **Subsystem**: `dlls/kernelbase/debug.c`
- **Problem**: `EnumProcessModules`, `GetModuleBaseName`, `GetModuleFileNameEx` and `GetModuleInformation` read the loader list in place for `GetCurrentProcess()`, but through `ReadProcessMemory` for a real process handle: one wineserver round trip per list entry. .NET's `System.Diagnostics.Process` opens a real handle to its own process and looks up each module in turn, walking the list again each time: 74,000 requests while Rhino 8 started (the Windows trace saw the same calls as 241,000 `NtReadVirtualMemory`).
- **Solution**: the module iterator already queries the process id; for the own process it reads the entries directly. Lookups through a real handle are six times faster; time to ready 6.8 s to 6.4 s, and wineserver requests during startup 179,000 to 91,000.

### Patch 39: COM Local Servers Without a Spinning Wait
- **File**: [`39-combase-local-server-wait.patch`](../patches/39-combase-local-server-wait.patch)
- **Subsystem**: `dlls/combase/rpc.c`
- **Problem**: after starting an out-of-process COM server, Wine polls rpcss once a second for its class object and waits in between on the server's process. A service has no process handle (and the handle was lost after the first poll anyway), and without one `CoWaitForMultipleHandles()` returns at once, so the wait loop spun for a full second at a time. Rhino 8 activates BITS (Background Intelligent Transfer Service) while it starts: a .NET worker burned a second of CPU, and Rhino's exit waited for it.
- **Solution**: keep the process handle for the whole wait, wait on an event nothing sets when there is no process, and poll after 10 ms, doubling up to a second, within the same 30-second limit. BITS is ready in 60 ms; Rhino exits a second sooner.

### Patch 40: Faster Environment Lookups
- **File**: [`40-ntdll-environment-scan.patch`](../patches/40-ntdll-environment-scan.patch)
- **Subsystem**: `dlls/ntdll/env.c`
- **Problem**: each environment variable lookup walks the whole environment block and measures every string with `wcslen()`, one character at a time. .NET's JIT reads `DOTNET_ReadPGOData` and `COMPlus_ReadPGOData` for every method it compiles: 28,000 lookups while Rhino 8 starts, about 0.1 s.
- **Solution**: the lookup finds each string's end four characters at a time (aligned 64-bit reads, which never cross a page).

