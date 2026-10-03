# Using Rhino on Tiling Window Managers (Niri, Hyprland, Sway)

CAD software is architecturally built around a multi-window floating paradigm: floating tool palettes, middle-click popup toolbars, dockable inspector panels, color pickers, and modal dialogs. 

Tiling window managers (like Niri, Hyprland, Sway, or i3) assume every newly created top-level window should tile and split screen space. Without custom window rules, running Rhino under a tiling compositor leads to UX issues:
- Middle-clicking creates the popup toolbox (`TabPanelDockBarFloatingForm`) as a tiled column or full-screen split instead of a small floater under the cursor.
- Auto-tiling compresses Rhino's 4-viewport layout into narrow columns (e.g. 50% width), causing continuous DXVK swapchain recreation loops (`VK_ERROR_OUT_OF_DATE_KHR`) and stutter.
- Under Wayland, X11 bridges (`xwayland-satellite`) can misroute pointer clicks across monitor boundaries unless Wine's coordinate origin is fixed (handled by Patch 20).

---

## Recommended Desktop Environments

For production CAD workflows, **stacking desktop environments are strongly recommended**:
- **KDE Plasma (KWin)**: First-class X11/Xwayland support, native floating behavior for tool palettes, static multi-monitor coordinate handling, and zero configuration required.
- **GNOME (Mutter)**: Reliable window management and solid Xwayland integration out of the box.

If you choose to use a tiling compositor, apply the window rules below.

---

## Configuration Guides

### 1. Niri

Edit `~/.config/niri/config.kdl`:

```kdl
// 1. Default all Rhino sub-windows, dialogs, and popups to float
window-rule {
    match app-id=r#"rhino\.exe$"#
    open-floating true
}

// 2. Only maximize the main Rhino workstation window
window-rule {
    match app-id=r#"rhino\.exe$"# title=r#"- Rhino"#
    open-maximized-to-edges true
}
```

#### Monitor Refresh Rates in Niri
Ensure your displays are running at their native refresh rates in `config.kdl` so DXVK viewport rendering is not capped to 60 Hz:

```kdl
output "HDMI-A-1" {
    mode "1920x1080@99.999" // Use your monitor's native mode from: niri msg outputs
    position x=0 y=0
}

output "eDP-1" {
    mode "1920x1080@144.001"
    position x=1920 y=0
}
```

Reload config:
```bash
niri msg action load-config-file
```

---

### 2. Hyprland

Edit `~/.config/hypr/hyprland.conf`:

```ini
# 1. Float all Rhino dialogs, palettes, and middle-click popups by default
windowrulev2 = float, class:^(rhino\.exe)$

# 2. Tile only the main Rhino workstation window
windowrulev2 = tile, class:^(rhino\.exe)$, title:(- Rhino)

# (Optional) Alternatively, auto-fullscreen the main window on its workspace:
# windowrulev2 = fullscreen, 1, class:^(rhino\.exe)$, title:(- Rhino)

# 3. Ensure the middle-click popup toolbar stays centered if it loses cursor focus
windowrulev2 = center, class:^(rhino\.exe)$, title:^(TabPanelDockBarFloatingForm)
```

Reload config:
```bash
hyprctl reload
```

---

### 3. Sway / i3

Edit `~/.config/sway/config` or `~/.config/i3/config`:

```
# Float all Rhino windows by default (dialogs, popups, palettes)
for_window [instance="rhino.exe"] floating enable

# Tile only the main workstation window
for_window [instance="rhino.exe" title="- Rhino"] floating disable
```

Reload config:
```bash
swaymsg reload
# or for i3:
# i3-msg reload
```

---

## Practical Advice for Tiling WMs

1. **Dedicate a Workspace**: Put Rhino on its own dedicated workspace on your primary display. Avoid splitting the workspace with terminals or browsers; Rhino needs full display dimensions for the 4-viewport grid to stay readable.
2. **Do Not Manually Resize Below Minimum Width**: Resizing a tiled Rhino column too narrowly causes continuous viewport swapchain recreation. Always keep the main window maximized or tiled to the full monitor width.
3. **Transient Popups Dismissal**: If a middle-click popup or dropdown does not dismiss immediately, click once inside any Rhino viewport to restore focus and close the transient window.
