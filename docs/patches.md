# Wine Patches Reference

This repository maintains 20 targeted patches against Wine (tested against Wine 11.18+) to run McNeel Rhinoceros 8 and Rhino 9 WIP smoothly on Linux.

Stock Wine encounters several critical blockers when running Rhino: multi-threaded OpenMP crashes, blank Cloud Zoo login windows (due to incomplete DirectComposition visual tree hosting), black borders around toolbars and menus, startup template screen dismissal, viewport rendering glitches upon maximizing, and multi-monitor coordinate bugs.

Below is the technical breakdown of all 20 patches.

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
- **Subsystem**: `dlls/user32/dialog.c`, `dlls/user32/user32.spec`
- **Problem**: Rhino's options, document properties, and print dialogs utilize Windows 10+ Per-Monitor DPI v2 APIs (`SetDialogDpiChangeBehavior`, `SetDialogControlDpiChangeBehavior`) to adjust dialog layout scaling when dragged across monitors of differing pixel densities. In stock Wine, these functions were absent, leading to dialog creation failures or misaligned fonts on multi-DPI displays.
- **Solution**: Implements `SetDialogDpiChangeBehavior` and `SetDialogControlDpiChangeBehavior` in `user32.dll`.

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
