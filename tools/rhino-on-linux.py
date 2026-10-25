#!/usr/bin/env python3
"""Rhino on Linux — a small setup and launch app for people who prefer not to
use the terminal. It drives the repository's own scripts (install.sh,
deploy-rhino.sh, rhino-9), so the app and the command line always do exactly
the same thing.

Requires: Python 3, PyGObject, GTK 4, libadwaita 1.5+.
"""
import os
import re
import shutil
import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402

APP_ID = "io.github.jabern.RhinoOnLinux"
REPO_DIR = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
HOME = os.path.expanduser("~")
IN_FLATPAK = bool(os.environ.get("FLATPAK_ID"))
DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
CONFIG_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "rhino-linux")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config")
GUI_SETTINGS = os.path.join(CONFIG_DIR, "app.ini")
DOWNLOAD_URL = "https://www.rhino3d.com/download/"
PLUGIN_SUFFIXES = ("rhi", "yak", "gha", "ghuser", "zip", "exe", "msi")
ANSI = re.compile(r"\x1b\[[0-9;]*m")

# Script output -> (progress fraction, friendly description), in installation order.
MILESTONES = [
    (re.compile(r"\[Step 1/4\]"), 0.03, "Checking your computer"),
    (re.compile(r"\[Step 2/4\]"), 0.08, "Getting the Windows compatibility layer"),
    (re.compile(r"\[1/6\]"), 0.25, "Preparing a private Windows environment"),
    (re.compile(r"\[2/6\]"), 0.40, "Setting up fast 3D graphics"),
    (re.compile(r"\[[34]/6\]"), 0.50, "Installing fonts and settings"),
    (re.compile(r"\[[56]/6\]"), 0.58, "Adding Rhino to your applications"),
    (re.compile(r"Installing \.NET Framework 4\.8"), 0.30, "Installing .NET Framework 4.8 for Rhino 7 — this takes 15 to 40 minutes"),
    (re.compile(r"Installing core fonts"), 0.45, "Installing fonts for Rhino 7"),
    (re.compile(r"Visual C\+\+ runtime"), 0.48, "Installing the Visual C++ runtime for Rhino 7"),
    (re.compile(r"Launching Rhino Installer"), 0.62, "Installing Rhino — the Rhino installer shows its own progress"),
    (re.compile(r"\[Step 4/4\]"), 0.97, "Checking the installation"),
]


def read_config():
    cfg = {}
    try:
        with open(CONFIG_FILE) as f:
            for line in f:
                m = re.match(r'\s*(\w+)="?(.*?)"?\s*$', line)
                if m:
                    cfg[m.group(1)] = m.group(2)
    except OSError:
        pass
    return cfg


def wine_path():
    return read_config().get("RHINO_WINE", os.path.join(DATA_HOME, "wine-rhino/bin/wine"))


# Rhino major versions, newest first, and their folders under Program Files.
# Each version has its own Wine prefix; tools/rhino-versions.sh has the same rules.
RHINO_VERSIONS = ("9", "8", "7")
RHINO_DIRS = {"9": ("Rhino 9", "Rhino 9 WIP"), "8": ("Rhino 8",), "7": ("Rhino 7",)}


def legacy_prefix():
    """The single prefix of releases before 1.2 (or a custom one saved then)."""
    default = os.path.join(DATA_HOME, "prefix") if IN_FLATPAK else os.path.join(HOME, ".wine-rhino")
    return read_config().get("RHINO_PREFIX", default)


def find_rhino_dir(prefix, version):
    for name in RHINO_DIRS[version]:
        if os.path.isfile(os.path.join(prefix, "drive_c/Program Files", name, "System/Rhino.exe")):
            return name
    return None


def prefix_for(version):
    saved = read_config().get(f"RHINO_PREFIX_{version}")
    if saved:
        return saved
    if find_rhino_dir(legacy_prefix(), version):
        return legacy_prefix()
    if IN_FLATPAK:
        return os.path.join(DATA_HOME, f"prefix-rhino{version}")
    return os.path.join(HOME, f".wine-rhino{version}")


def installed_versions():
    """Installed major versions, newest first."""
    return [v for v in RHINO_VERSIONS if find_rhino_dir(prefix_for(v), v)]


def rhino_name(version):
    """Rhino's folder under Program Files for this version, e.g. "Rhino 9 WIP"."""
    return find_rhino_dir(prefix_for(version), version)


def rhino_installed():
    return bool(installed_versions())


def version_from_installer(path):
    """rhino_en-us_8.36….exe -> "8"; None when the name does not say."""
    m = re.match(r"rhino[_-]([a-z]{2}-[a-z]{2}[_-])?(\d+)\.", os.path.basename(path or "").lower())
    return m.group(2) if m and m.group(2) in RHINO_VERSIONS else None


def launcher():
    if IN_FLATPAK:
        return shutil.which("rhino-9") or "rhino-9"
    local = os.path.join(HOME, ".local/bin/rhino-9")
    return local if os.path.exists(local) else (shutil.which("rhino-9") or local)


def run_quiet(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def menu_files(version):
    """The menu entry and icon rhino_write_menu_entries writes for a version, in
    the host's ~/.local/share (HOME is the real home folder in the Flatpak)."""
    share = os.path.join(HOME, ".local/share")
    if IN_FLATPAK:
        entry, icon = f"{os.environ['FLATPAK_ID']}.Rhino{version}.desktop", f"{os.environ['FLATPAK_ID']}.Rhino{version}.png"
    else:
        entry, icon = f"rhino-{version}-version.desktop", f"rhino-on-linux-rhino{version}.png"
    return [os.path.join(share, "applications", entry), os.path.join(share, "icons/hicolor/256x256/apps", icon)]


def refresh_menu_entries():
    """One menu entry per installed version, in the background; also brings the
    entries of an earlier release up to date."""
    try:
        subprocess.Popen(["bash", "-c", '. "$1" && rhino_write_menu_entries', "bash",
                          os.path.join(REPO_DIR, "tools", "rhino-versions.sh")],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


# --- system checks -------------------------------------------------------------

def check_graphics():
    summary = run_quiet("vulkaninfo", "--summary")
    names = re.findall(r"deviceName\s*=\s*(.+)", summary)
    gpus = [n.strip() for n in names if "llvmpipe" not in n.lower()]
    if gpus:
        return True, "3D graphics ready", gpus[0]
    if names:
        return False, "No 3D graphics driver", "Only software rendering was found. Install the driver for your graphics card."
    if run_quiet("sh", "-c", "ldconfig -p | grep -q libvulkan.so.1 && echo yes").strip():
        return True, "3D graphics available", "Vulkan is installed"
    return False, "3D graphics are not set up", "Install the Vulkan driver for your graphics card (your distribution's driver manager can do this)."


def check_disk():
    free_gb = shutil.disk_usage(HOME).free / 1e9
    if free_gb >= 15:
        return True, "Enough free space", f"{free_gb:.0f} GB free"
    return False, "Low disk space", f"{free_gb:.0f} GB free — Rhino needs about 15 GB"


def check_tools():
    missing = [t for t in ("curl", "tar") if not shutil.which(t)]
    if not any(shutil.which(t) for t in ("cabextract", "bsdtar", "7z")):
        missing.append("cabextract")
    if not missing:
        return True, "Everything needed is installed", "curl, tar and an archive tool are present"
    return False, "A few small tools are missing", "Please install: " + ", ".join(missing)


NTSYNC_COMMAND = "echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf && sudo modprobe ntsync"


def ntsync_state():
    """'on', 'off' (the kernel has ntsync, usually as a module that is not
    loaded) or 'old' (the kernel predates ntsync, added in Linux 6.14)."""
    if os.access("/dev/ntsync", os.R_OK | os.W_OK):
        return "on"
    m = re.match(r"(\d+)\.(\d+)", os.uname().release)
    return "off" if m and (int(m.group(1)), int(m.group(2))) >= (6, 14) else "old"


def check_sync():
    state = ntsync_state()
    if state == "on":
        return True, "Fast multithreading available", "Your kernel supports ntsync"
    if state == "off":
        return True, "Fast multithreading is switched off", "Optional: one command turns on ntsync, which makes Rhino a little faster"
    return True, "Standard multithreading", "Optional: Linux 6.14 or newer comes with ntsync, which makes Rhino a little faster"


CHECKS = [check_graphics, check_disk, check_tools, check_sync]


def app_icon_path():
    """Rhino's icon: the copy deploy-rhino.sh installs, else the one shipped with this app
    (a fresh install has not run the deploy step yet)."""
    data = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
    for path in (os.path.join(data, "rhino-linux/rhino9-256.png"), os.path.join(REPO_DIR, "tools/rhino9-256.png")):
        if os.path.isfile(path):
            return path
    return None


def app_status_page(title, description):
    """Status page showing Rhino's icon when the deploy step has installed it."""
    page = Adw.StatusPage(title=title, description=description)
    icon = app_icon_path()
    try:
        page.set_paintable(Gdk.Texture.new_from_filename(icon))
    except (GLib.Error, TypeError):
        page.set_icon_name("applications-graphics-symbolic")
    return page


def app_header(title, description):
    """Compact icon and title for pages with more content below."""
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_top=12)
    icon = app_icon_path()
    if icon:
        box.append(Gtk.Image(file=icon, pixel_size=96, margin_bottom=6))
    else:
        box.append(Gtk.Image(icon_name="applications-graphics-symbolic", pixel_size=96, margin_bottom=6))
    label = Gtk.Label(label=title)
    label.add_css_class("title-1")
    box.append(label)
    box.append(Gtk.Label(label=description, wrap=True, justify=Gtk.Justification.CENTER))
    return box


def find_installer():
    downloads = os.path.join(HOME, "Downloads")
    try:
        found = [os.path.join(downloads, f) for f in os.listdir(downloads)
                 if f.lower().startswith("rhino") and f.lower().endswith(".exe")]
    except OSError:
        return None
    return max(found, key=os.path.getmtime) if found else None


# --- user interface -----------------------------------------------------------

class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Rhino on Linux", default_width=640, default_height=720)
        self.expert = self.load_expert()
        self.installer = find_installer()
        self.install_version = version_from_installer(self.installer) or "8"
        self.tool_version = None
        self.log_lines = []
        self.proc = None
        self.exit_status = 0

        self.toasts = Adw.ToastOverlay()
        self.nav = Adw.NavigationView()
        self.toasts.set_child(self.nav)
        self.set_content(self.toasts)

        drop = Gtk.DropTarget.new(Gio.File, Gdk.DragAction.COPY)
        drop.connect("drop", lambda _t, f, _x, _y: self.install_plugin(f.get_path()) or True)
        self.toasts.add_controller(drop)

        action = Gio.SimpleAction.new_stateful("expert", None, GLib.Variant.new_boolean(self.expert))
        action.connect("change-state", self.on_expert)
        self.add_action(action)
        for name, cb in (("about", self.on_about), ("report", self.on_report)):
            a = Gio.SimpleAction.new(name, None)
            a.connect("activate", cb)
            self.add_action(a)
        for name, cb in (("repair-version", lambda _a, v: self.repair([v.get_string()])),
                         ("uninstall-version", lambda _a, v: self.on_uninstall(version=v.get_string()))):
            a = Gio.SimpleAction.new(name, GLib.VariantType.new("s"))
            a.connect("activate", cb)
            self.add_action(a)

        self.show_start()

    # settings
    def load_expert(self):
        try:
            with open(GUI_SETTINGS) as f:
                return "expert=1" in f.read()
        except OSError:
            return False

    def save_expert(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(GUI_SETTINGS, "w") as f:
            f.write(f"expert={int(self.expert)}\n")

    # common page scaffolding
    def page(self, title, child, tag):
        header = Adw.HeaderBar()
        menu = Gio.Menu()
        menu.append("Expert mode", "win.expert")
        menu.append("Create a problem report", "win.report")
        menu.append("About", "win.about")
        header.pack_end(Gtk.MenuButton(icon_name="open-menu-symbolic", menu_model=menu, tooltip_text="Menu"))
        view = Adw.ToolbarView()
        view.add_top_bar(header)
        scroll = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER, propagate_natural_height=True)
        clamp = Adw.Clamp(maximum_size=560, child=child, margin_top=12, margin_bottom=24, margin_start=12, margin_end=12)
        scroll.set_child(clamp)
        view.set_content(scroll)
        return Adw.NavigationPage(title=title, child=view, tag=tag)

    @staticmethod
    def pill(label, primary=True):
        b = Gtk.Button(label=label, halign=Gtk.Align.CENTER)
        b.add_css_class("pill")
        if primary:
            b.add_css_class("suggested-action")
        return b

    def toast(self, text):
        self.toasts.add_toast(Adw.Toast(title=text, timeout=4))

    def show_start(self):
        self.nav.replace([self.home_page() if rhino_installed() else self.welcome_page()])

    # welcome -> checks -> installer -> install -> done
    def welcome_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        status = app_status_page("Welcome", "Let's get Rhino running on Linux.\n"
                                            "This takes a few minutes and needs no terminal.")
        box.append(status)
        start = self.pill("Get Started")
        start.connect("clicked", lambda *_: self.nav.push(self.checks_page()))
        box.append(start)
        return self.page("Rhino on Linux", box, "welcome")

    def checks_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        group = Adw.PreferencesGroup(title="Your computer",
                                     description="Checking that everything Rhino needs is in place.")
        ok_all = True
        for check in CHECKS:
            ok, title, detail = check()
            ok_all &= ok
            row = Adw.ActionRow(title=title, subtitle=detail)
            icon = Gtk.Image(icon_name="object-select-symbolic" if ok else "dialog-warning-symbolic")
            icon.add_css_class("success" if ok else "warning")
            row.add_prefix(icon)
            group.add(row)
        box.append(group)
        if not ok_all:
            box.append(Gtk.Label(label="You can continue, but fix the warnings above if Rhino does not start.",
                                 wrap=True, css_classes=["dim-label"]))
        nxt = self.pill("Continue")
        nxt.connect("clicked", lambda *_: self.nav.push(self.installer_page()))
        box.append(nxt)
        return self.page("Check", box, "checks")

    def installer_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        group = Adw.PreferencesGroup(title="The Rhino installer",
                                     description="Download Rhino 7, 8 or 9 from McNeel with your account, then choose the file here. "
                                                 "Each version gets its own Windows environment, so several can be installed side by side.")
        get = Adw.ActionRow(title="Download Rhino", subtitle="Opens the official download page", activatable=True)
        get.add_suffix(Gtk.Image(icon_name="web-browser-symbolic"))
        get.connect("activated", lambda *_: Gtk.UriLauncher(uri=DOWNLOAD_URL).launch(self, None, None, None))
        group.add(get)
        self.file_row = Adw.ActionRow(title="Installer file", activatable=True)
        self.file_row.add_suffix(Gtk.Image(icon_name="document-open-symbolic"))
        self.file_row.connect("activated", self.on_choose_file)
        group.add(self.file_row)
        # Shown when the file name does not tell which version it installs.
        self.version_row = Adw.ComboRow(title="Rhino version", subtitle="The file name does not say which version this is",
                                        model=Gtk.StringList.new([f"Rhino {v}" for v in RHINO_VERSIONS]))
        self.version_row.connect("notify::selected", self.on_version_selected)
        group.add(self.version_row)
        box.append(group)
        self.version_note = Gtk.Label(wrap=True, justify=Gtk.Justification.CENTER, css_classes=["dim-label"])
        box.append(self.version_note)
        self.install_btn = self.pill("Install Rhino")
        self.install_btn.connect("clicked", lambda *_: self.start_install())
        box.append(self.install_btn)
        self.update_file_row()
        return self.page("Installer", box, "installer")

    def on_version_selected(self, row, _pspec):
        self.install_version = RHINO_VERSIONS[row.get_selected()]
        self.update_version_note()

    def update_version_note(self):
        v = self.install_version
        notes = []
        if v in installed_versions():
            notes.append(f"{rhino_name(v)} is already installed: this updates it, keeping your settings and sign-in.")
        if v == "7":
            notes.append("Rhino 7 needs Microsoft's .NET Framework 4.8, which this app installs first. "
                         "That makes the first installation take 30 to 60 minutes.")
        self.version_note.set_label("\n\n".join(notes))
        self.version_note.set_visible(bool(notes))
        self.install_btn.set_label(f"Install Rhino {v}" if self.installer else "Install Rhino")

    def update_file_row(self):
        detected = version_from_installer(self.installer)
        if self.installer:
            what = f" — Rhino {detected}" if detected else ""
            self.file_row.set_subtitle(os.path.basename(self.installer) + what)
        else:
            self.file_row.set_subtitle("Choose the downloaded rhino_….exe")
        if detected:
            self.install_version = detected
        self.version_row.set_visible(bool(self.installer) and not detected)
        self.version_row.set_selected(RHINO_VERSIONS.index(self.install_version))
        self.install_btn.set_sensitive(bool(self.installer))
        self.update_version_note()

    def on_choose_file(self, *_):
        dialog = Gtk.FileDialog(title="Choose the Rhino installer")
        flt = Gtk.FileFilter(name="Windows installers")
        flt.add_suffix("exe")
        filters = Gio.ListStore.new(Gtk.FileFilter)
        filters.append(flt)
        dialog.set_filters(filters)
        if os.path.isdir(os.path.join(HOME, "Downloads")):
            dialog.set_initial_folder(Gio.File.new_for_path(os.path.join(HOME, "Downloads")))

        def done(dlg, res):
            try:
                f = dlg.open_finish(res)
            except GLib.Error:
                return
            self.installer = f.get_path()
            self.update_file_row()
        dialog.open(self, None, done)

    # running the scripts
    def progress_page(self, title):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18, margin_top=24)
        if hasattr(Adw, "Spinner"):  # libadwaita 1.6+
            self.spinner = Adw.Spinner(height_request=48)
        else:
            self.spinner = Gtk.Spinner(spinning=True, height_request=48)
        box.append(self.spinner)
        self.step_label = Gtk.Label(label="Starting…", wrap=True, justify=Gtk.Justification.CENTER)
        self.step_label.add_css_class("title-3")
        box.append(self.step_label)
        self.bar = Gtk.ProgressBar(margin_start=24, margin_end=24)
        box.append(self.bar)
        self.log_view = Gtk.TextView(editable=False, monospace=True, wrap_mode=Gtk.WrapMode.WORD_CHAR,
                                     top_margin=8, bottom_margin=8, left_margin=8, right_margin=8)
        log_scroll = Gtk.ScrolledWindow(min_content_height=260, child=self.log_view)
        log_scroll.add_css_class("card")
        expander = Gtk.Expander(label="Details", child=log_scroll, expanded=self.expert)
        box.append(expander)
        page = self.page(title, box, "progress")
        page.set_can_pop(False)
        return page

    def run_script(self, title, argv, on_done):
        self.log_lines = []
        self.nav.push(self.progress_page(title))
        env = dict(os.environ)
        env.pop("WINEDLLOVERRIDES", None)
        launcher_ = Gio.SubprocessLauncher.new(Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE)
        for k, v in env.items():
            launcher_.setenv(k, v, True)
        launcher_.set_cwd(REPO_DIR)
        try:
            self.proc = launcher_.spawnv(argv)
        except GLib.Error as e:
            self.finish(False, str(e), on_done)
            return
        stream = Gio.DataInputStream.new(self.proc.get_stdout_pipe())
        self.read_line(stream, on_done)

    def read_line(self, stream, on_done):
        def got(src, res):
            line, _ = src.read_line_finish_utf8(res)
            if line is None:
                self.proc.wait_check_async(None, lambda p, r: self.on_exit(p, r, on_done))
                return
            self.on_output(ANSI.sub("", line))
            self.read_line(stream, on_done)
        stream.read_line_async(GLib.PRIORITY_DEFAULT, None, got)

    def on_output(self, line):
        self.log_lines.append(line)
        buf = self.log_view.get_buffer()
        buf.insert(buf.get_end_iter(), line + "\n")
        self.log_view.scroll_to_mark(buf.get_insert(), 0, False, 0, 0)
        for pattern, fraction, text in MILESTONES:
            if pattern.search(line) and fraction >= self.bar.get_fraction():
                self.bar.set_fraction(fraction)
                self.step_label.set_label(text)

    def on_exit(self, proc, res, on_done):
        try:
            ok = proc.wait_check_finish(res)
        except GLib.Error:
            ok = False
        self.exit_status = proc.get_exit_status() if proc.get_if_exited() else -1
        tail = "\n".join(l for l in self.log_lines[-8:] if l.strip())
        self.finish(ok, tail, on_done)

    def finish(self, ok, detail, on_done):
        self.proc = None
        self.spinner.set_visible(False)
        self.bar.set_fraction(1.0 if ok else self.bar.get_fraction())
        on_done(ok, detail)

    def start_install(self):
        argv = [os.path.join(REPO_DIR, "install.sh"), "-y", "--installer", self.installer,
                "--version", self.install_version]
        self.run_script(f"Installing Rhino {self.install_version}", argv, self.install_done)

    def install_done(self, ok, detail):
        v = self.install_version
        if ok and v in installed_versions():
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
            box.append(Adw.StatusPage(icon_name="object-select-symbolic", title=f"{rhino_name(v)} is ready",
                                      description="You'll also find Rhino in your applications menu. "
                                                  "The first start asks you to sign in with your Rhino account."))
            open_btn = self.pill(f"Open {rhino_name(v)}")
            open_btn.connect("clicked", lambda *_: self.on_open_rhino(v))
            box.append(open_btn)
            self.nav.replace([self.home_page(), self.page("Done", box, "done")])
        else:
            self.show_failure("The installation did not finish", detail)

    def show_failure(self, title, detail):
        dialog = Adw.AlertDialog(heading=title,
                                 body="Nothing was lost. You can try again, or create a problem report "
                                      "(menu → Create a problem report) and share it with us.")
        if detail:
            label = Gtk.Label(label=detail, wrap=True, xalign=0, selectable=True)
            label.add_css_class("monospace")
            label.add_css_class("caption")
            dialog.set_extra_child(Gtk.Expander(label="Technical details", child=label, expanded=self.expert))
        dialog.add_response("ok", "OK")
        if self.nav.get_visible_page().get_tag() == "progress":
            self.nav.pop()
        dialog.present(self)

    # home screen for an existing installation
    def home_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        versions = installed_versions()
        if len(versions) == 1:
            v = versions[0]
            box.append(app_header(rhino_name(v), "Installed and ready."))
            open_btn = self.pill("Open Rhino")
            open_btn.connect("clicked", lambda *_: self.on_open_rhino(v))
            box.append(open_btn)
        else:
            box.append(app_header("Rhino on Linux", f"{len(versions)} versions of Rhino are installed."))
        box.append(self.versions_group(versions))

        plugins = Adw.PreferencesGroup(title="Plug-ins",
                                       description="You can also drop a plug-in file on this window, or double-click it in your file manager.")
        row = Adw.ActionRow(title="Install a plug-in…", subtitle="Bella, V-Ray, Grasshopper add-ons: .rhi, .yak, .gha, .zip or an installer",
                            activatable=True)
        row.add_prefix(Gtk.Image(icon_name="list-add-symbolic"))
        row.connect("activated", self.on_choose_plugin)
        plugins.add(row)
        box.append(plugins)

        if ntsync_state() == "off":
            box.append(self.ntsync_group())

        group = Adw.PreferencesGroup(title="Maintenance")
        for title, subtitle, icon, cb in (
            ("Check for updates", "Get the newest fixes for Rhino on Linux", "software-update-available-symbolic", self.on_update),
            ("Repair", "Restore the settings Rhino needs, keeping your files and sign-in", "applications-engineering-symbolic", self.on_repair),
            ("Rhino is stuck", "Close every part of Rhino that is still running", "process-stop-symbolic", self.on_stop),
            ("Uninstall", "Remove Rhino and everything this app installed", "user-trash-symbolic", self.on_uninstall),
        ):
            row = Adw.ActionRow(title=title, subtitle=subtitle, activatable=True)
            row.add_prefix(Gtk.Image(icon_name=icon))
            row.connect("activated", cb)
            group.add(row)
        box.append(group)

        if self.expert:
            box.append(self.expert_group())
        return self.page("Rhino on Linux", box, "home")

    def versions_group(self, versions):
        """One row per installed Rhino, plus a row to add another version."""
        group = Adw.PreferencesGroup(title="Installed" if len(versions) > 1 else "")
        if len(versions) > 1:
            for v in versions:
                row = Adw.ActionRow(title=rhino_name(v), subtitle=prefix_for(v) if self.expert else "Ready")
                open_btn = Gtk.Button(label="Open", valign=Gtk.Align.CENTER)
                open_btn.add_css_class("suggested-action")
                open_btn.connect("clicked", lambda _b, v=v: self.on_open_rhino(v))
                row.add_suffix(open_btn)
                row.add_suffix(self.version_menu(v))
                group.add(row)
        missing = [v for v in RHINO_VERSIONS if v not in versions]
        if missing:
            add = Adw.ActionRow(title="Install another Rhino version…",
                                subtitle="Rhino " + ", ".join(missing) + " can be installed next to "
                                         + ("it" if len(versions) == 1 else "them"),
                                activatable=True)
            add.add_prefix(Gtk.Image(icon_name="list-add-symbolic"))
            add.connect("activated", lambda *_: self.on_add_version(missing[0]))
            group.add(add)
        return group

    def version_menu(self, version):
        """Repair or uninstall one version."""
        menu = Gio.Menu()
        menu.append("Repair", f"win.repair-version('{version}')")
        menu.append("Uninstall…", f"win.uninstall-version('{version}')")
        button = Gtk.MenuButton(icon_name="view-more-symbolic", menu_model=menu, valign=Gtk.Align.CENTER,
                                tooltip_text=f"Rhino {version}")
        button.add_css_class("flat")
        return button

    def on_add_version(self, suggested):
        self.installer = None
        self.install_version = suggested
        self.nav.push(self.installer_page())

    def ntsync_group(self):
        group = Adw.PreferencesGroup(
            title="Make Rhino faster",
            description="Your Linux kernel has ntsync, which speeds up Rhino's multithreaded work, but it is "
                        "switched off. Run this command once in a terminal; it asks for your password and "
                        "stays on after a restart. Then restart Rhino.")
        row = Adw.ActionRow(title=NTSYNC_COMMAND, title_selectable=True, use_markup=False)
        row.add_css_class("monospace")
        copy = Gtk.Button(icon_name="edit-copy-symbolic", valign=Gtk.Align.CENTER, tooltip_text="Copy")
        copy.add_css_class("flat")

        def copied(*_):
            self.get_clipboard().set(NTSYNC_COMMAND)
            self.toast("Command copied")
        copy.connect("clicked", copied)
        row.add_suffix(copy)
        group.add(row)
        return group

    def expert_group(self):
        group = Adw.PreferencesGroup(title="Expert", description="Direct access to the Wine environments.")
        wine = wine_path()
        version = run_quiet(wine, "--version").strip() or "not found"
        group.add(Adw.ActionRow(title="Wine runtime", subtitle=f"{version} — {os.path.dirname(os.path.dirname(wine))}"))
        versions = installed_versions() or ["8"]
        if self.tool_version not in versions:
            self.tool_version = versions[0]
        for v in versions:
            prefix = prefix_for(v)
            prefix_row = Adw.ActionRow(title=f"Prefix of {rhino_name(v) or 'Rhino ' + v}", subtitle=prefix, activatable=True)
            prefix_row.add_suffix(Gtk.Image(icon_name="folder-open-symbolic"))
            prefix_row.connect("activated", lambda _r, p=prefix: self.open_path(p))
            group.add(prefix_row)
        if len(versions) > 1:
            chooser = Adw.ComboRow(title="Tools below act on", model=Gtk.StringList.new([rhino_name(v) for v in versions]),
                                   selected=versions.index(self.tool_version))
            chooser.connect("notify::selected", lambda row, _p: setattr(self, "tool_version", versions[row.get_selected()]))
            group.add(chooser)
        tools = [("Wine configuration", lambda *_: self.wine_tool("winecfg")),
                 ("Registry editor", lambda *_: self.wine_tool("regedit")),
                 ("Edit DXVK settings", lambda *_: self.open_path(self.dxvk_conf()))]
        if not IN_FLATPAK:  # the sandbox has no host terminal and no Wine toolchain
            tools += [("Open a terminal in the prefix", self.on_terminal),
                      ("Rebuild Wine from source", self.on_rebuild)]
        for title, cb in tools:
            row = Adw.ActionRow(title=title, activatable=True)
            row.add_suffix(Gtk.Image(icon_name="go-next-symbolic"))
            row.connect("activated", cb)
            group.add(row)
        return group

    def on_open_rhino(self, version=None, *_):
        versions = installed_versions()
        if version not in RHINO_VERSIONS:
            version = versions[0] if versions else None
        try:
            subprocess.Popen([launcher()] + (["--version", version] if version else []), start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.toast(f"Opening {rhino_name(version) or 'Rhino'}…")
        except OSError as e:
            self.show_failure("Rhino could not be started", str(e))

    def on_choose_plugin(self, *_):
        dialog = Gtk.FileDialog(title="Choose a Rhino plug-in")
        flt = Gtk.FileFilter(name="Rhino and Grasshopper plug-ins")
        for suffix in PLUGIN_SUFFIXES:
            flt.add_suffix(suffix)
        filters = Gio.ListStore.new(Gtk.FileFilter)
        filters.append(flt)
        dialog.set_filters(filters)
        if os.path.isdir(os.path.join(HOME, "Downloads")):
            dialog.set_initial_folder(Gio.File.new_for_path(os.path.join(HOME, "Downloads")))

        def done(dlg, res):
            try:
                self.install_plugin(dlg.open_finish(res).get_path())
            except GLib.Error:
                pass
        dialog.open(self, None, done)

    def install_plugin(self, path, version=None):
        if self.proc is not None:
            self.toast("Please wait until this step finishes")
            return
        if not path or not path.lower().endswith(tuple("." + s for s in PLUGIN_SUFFIXES)):
            self.show_failure("This is not a Rhino plug-in",
                              "Supported files: " + ", ".join("." + s for s in PLUGIN_SUFFIXES))
            return
        versions = installed_versions()
        if not versions:
            self.show_failure("Install Rhino first", "Plug-ins are added to an existing Rhino installation.")
            return
        if version is None and len(versions) > 1:
            dialog = Adw.AlertDialog(heading="Which Rhino?",
                                     body=f"Add {os.path.basename(path)} to which version of Rhino?")
            dialog.add_response("cancel", "Cancel")
            for v in versions:
                dialog.add_response(v, rhino_name(v))
            dialog.set_response_appearance(versions[0], Adw.ResponseAppearance.SUGGESTED)
            dialog.set_close_response("cancel")

            def chosen(dlg, res):
                answer = dlg.choose_finish(res)
                if answer in versions:
                    self.install_plugin(path, answer)
            dialog.choose(self, None, chosen)
            return
        version = version or versions[0]
        name = os.path.basename(path)
        argv = [os.path.join(REPO_DIR, "tools/install-plugin.sh"), "--version", version, path]
        self.run_script("Installing " + name, argv, lambda ok, d: self.plugin_done(ok, d, path, version))
        if name.lower().endswith((".exe", ".msi")):
            self.step_label.set_label("Follow the steps in the installer window")

    def plugin_done(self, ok, detail, path, version=None):
        if ok:
            self.nav.replace([self.home_page()])
            self.toast(os.path.basename(path) + " installed. Restart Rhino to use it.")
        elif self.exit_status == 3:
            self.nav.pop()
            dialog = Adw.AlertDialog(heading="Close Rhino first",
                                     body="Plug-ins are installed while Rhino is closed. Save your work in Rhino, "
                                          "then close it, or let this app close it for you.")
            dialog.add_response("cancel", "Cancel")
            dialog.add_response("close", "Close Rhino and Install")
            dialog.set_response_appearance("close", Adw.ResponseAppearance.DESTRUCTIVE)
            dialog.set_close_response("cancel")

            def chosen(dlg, res):
                if dlg.choose_finish(res) == "close":
                    self.on_stop()
                    self.install_plugin(path, version)
            dialog.choose(self, None, chosen)
        else:
            self.show_failure("The plug-in was not installed", detail)

    def on_update(self, *_):
        self.run_script("Updating", [os.path.join(REPO_DIR, "install.sh"), "-y"],
                        lambda ok, d: self.after_maintenance(ok, d, "Rhino on Linux is up to date"))

    def on_repair(self, *_):
        self.repair(installed_versions())

    def repair(self, versions):
        """deploy-rhino.sh for each version in turn."""
        deploy = os.path.join(REPO_DIR, "tools/deploy-rhino.sh")
        steps = [f'"{deploy}" --prefix "{prefix_for(v)}" --wine "{wine_path()}" --version {v}' for v in versions]
        argv = ["bash", "-c", " && ".join(steps) or "true"]
        names = " and ".join(rhino_name(v) for v in versions) or "Rhino"
        self.run_script("Repairing " + names, argv, lambda ok, d: self.after_maintenance(ok, d, "Repair finished"))

    def on_rebuild(self, *_):
        self.run_script("Building Wine", [os.path.join(REPO_DIR, "install.sh"), "-y", "--build-wine"],
                        lambda ok, d: self.after_maintenance(ok, d, "Wine was rebuilt"))

    def after_maintenance(self, ok, detail, message):
        if ok:
            self.nav.replace([self.home_page()])
            self.toast(message)
        else:
            self.show_failure("That did not work", detail)

    def on_stop(self, *_):
        try:
            subprocess.run([launcher(), "--stop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
            self.toast("Rhino was closed")
        except (OSError, subprocess.SubprocessError):
            self.toast("Rhino is not running")

    def uninstall_targets(self, version=None):
        """Only paths this project created: Wine prefixes, our runtime, our files.
        With a version, only that version's prefix."""
        data = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
        prefixes = {prefix_for(v) for v in ([version] if version else RHINO_VERSIONS)}
        if not version:
            prefixes.add(legacy_prefix())
        elif any(prefix_for(v) == prefix_for(version) for v in RHINO_VERSIONS if v != version and v in installed_versions()):
            prefixes = set()  # an old shared prefix also holds another version: keep it
        targets = sorted(p for p in prefixes if os.path.isdir(os.path.join(p, "drive_c")))
        if version:
            return self.safe_targets(targets + menu_files(version) if targets else [])
        runtime = os.path.dirname(os.path.dirname(wine_path()))
        if os.path.exists(os.path.join(runtime, ".rhino-linux-runtime")) or os.path.basename(runtime) == "wine-rhino":
            targets.append(runtime)
        cache = os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache"))
        targets += [os.path.join(data, "rhino-linux"), CONFIG_DIR, os.path.join(cache, "rhino-linux")]
        targets += [f for v in RHINO_VERSIONS for f in menu_files(v)]
        if IN_FLATPAK:
            # The sandbox's own cache: Wine Mono/Gecko and DXVK's shader cache.
            # Nothing outside ~/.var/app: HOME is the real home folder here.
            targets += [os.path.join(cache, "wine"), os.path.join(cache, "dxvk")]
        else:
            apps = os.path.join(data, "applications")
            targets += [os.path.join(HOME, ".local/bin", n) for n in ("rhino-9", "rhino-8", "rhino-7")]
            targets += [os.path.join(apps, "rhino-9.desktop"), os.path.join(apps, "io.github.jabern.RhinoOnLinux.desktop")]
            targets += [os.path.join(data, "mime/packages/io.github.jabern.RhinoOnLinux.xml"),
                        os.path.join(data, "icons/hicolor/256x256/apps/rhino9.png")]
        return self.safe_targets(targets)

    @staticmethod
    def safe_targets(targets):
        safe = []
        for t in targets:
            real = os.path.realpath(t)
            if os.path.lexists(t) and real.startswith(HOME + os.sep) and real != HOME:
                safe.append(t)
        return safe

    def on_uninstall(self, *_, version=None):
        versions = installed_versions()
        if version is None and len(versions) > 1:
            dialog = Adw.AlertDialog(heading="Uninstall which Rhino?",
                                     body="Remove one version, or every version together with this app's files.")
            dialog.add_response("cancel", "Cancel")
            for v in versions:
                dialog.add_response(v, rhino_name(v))
            dialog.add_response("all", "Everything")
            dialog.set_response_appearance("all", Adw.ResponseAppearance.DESTRUCTIVE)
            dialog.set_close_response("cancel")

            def picked(dlg, res):
                answer = dlg.choose_finish(res)
                if answer == "all":
                    self.confirm_uninstall(None)
                elif answer in versions:
                    self.confirm_uninstall(answer)
            dialog.choose(self, None, picked)
            return
        self.confirm_uninstall(version)

    def confirm_uninstall(self, version):
        targets = self.uninstall_targets(version)
        if version and not targets:
            self.show_failure(f"{rhino_name(version)} shares its environment with another version",
                              "It was installed with an older release of this app, in the same Windows environment as "
                              "another Rhino. Use Rhino's own uninstaller (Windows Settings) or uninstall everything.")
            return
        what = rhino_name(version) if version else "Rhino"
        dialog = Adw.AlertDialog(heading=f"Uninstall {what}?",
                                 body=f"This removes {what}, its settings and the Windows environment it runs in:\n\n"
                                      + "\n".join(targets) + "\n\nYour own models in Documents are not touched.")
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("remove", "Uninstall")
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_close_response("cancel")

        def chosen(dlg, res):
            if dlg.choose_finish(res) != "remove":
                return
            self.on_stop()
            self.remove_targets(targets)
            self.show_start()
            self.toast(f"{what} was uninstalled")
        dialog.choose(self, None, chosen)

    def remove_targets(targets):
        for t in targets:
            if os.path.isdir(t) and not os.path.islink(t):
                shutil.rmtree(t, ignore_errors=True)
            else:
                try:
                    os.unlink(t)
                except OSError:
                    pass
        if not IN_FLATPAK:
            run_quiet("update-mime-database", os.path.join(DATA_HOME, "mime"))
            run_quiet("update-desktop-database", os.path.join(DATA_HOME, "applications"))

    def dxvk_conf(self):
        data = os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share"))
        return os.path.join(data, "rhino-linux/dxvk-rhino.conf")

    def open_path(self, path):
        Gtk.FileLauncher(file=Gio.File.new_for_path(path)).launch(self, None, None, None)

    def tool_prefix(self):
        versions = installed_versions()
        version = self.tool_version if self.tool_version in versions else (versions[0] if versions else "8")
        return prefix_for(version)

    def wine_tool(self, tool):
        env = dict(os.environ, WINEPREFIX=self.tool_prefix())
        subprocess.Popen([wine_path(), tool], env=env, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def on_terminal(self, *_):
        prefix = self.tool_prefix()
        env = dict(os.environ, WINEPREFIX=prefix,
                   PATH=os.path.dirname(wine_path()) + os.pathsep + os.environ.get("PATH", ""))
        for term in (os.environ.get("TERMINAL"), "kgx", "gnome-terminal", "konsole", "xfce4-terminal", "xterm"):
            if term and shutil.which(term):
                subprocess.Popen([term], cwd=prefix, env=env, start_new_session=True)
                return
        self.toast("No terminal application found")

    def on_report(self, *_):
        lines = ["Rhino on Linux problem report", ""]
        lines += ["== System", run_quiet("uname", "-sr").strip(),
                  run_quiet("sh", "-c", ". /etc/os-release; echo $PRETTY_NAME").strip(),
                  "session: " + os.environ.get("XDG_SESSION_TYPE", "?") + " / " + os.environ.get("XDG_CURRENT_DESKTOP", "?")]
        lines += ["", "== Graphics"] + [l for l in run_quiet("vulkaninfo", "--summary").splitlines()
                                         if re.search(r"deviceName|driverName|driverInfo|apiVersion", l)]
        lines += ["", "== Wine", run_quiet(wine_path(), "--version").strip(), "ntsync: " + ntsync_state()]
        lines += [f"Rhino {v}: " + (f"{rhino_name(v)} in {prefix_for(v)}" if v in installed_versions() else "not installed")
                  for v in RHINO_VERSIONS]
        if self.log_lines:
            lines += ["", "== Last setup output"] + self.log_lines[-200:]
        path = os.path.join(HOME, "rhino-on-linux-report.txt")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        self.toast("Report saved to your home folder")
        self.open_path(os.path.dirname(path))

    def on_expert(self, action, value):
        action.set_state(value)
        self.expert = value.get_boolean()
        self.save_expert()
        if self.proc is None:
            self.show_start()

    def on_about(self, *_):
        about = Adw.AboutDialog(application_name="Rhino on Linux", developer_name="Rhino on Linux contributors",
                                website="https://github.com/Jabern/rhino-linux",
                                issue_url="https://github.com/Jabern/rhino-linux/issues",
                                license_type=Gtk.License.MIT_X11,
                                comments="Sets up and launches McNeel Rhinoceros with Wine and DXVK. "
                                         "Not affiliated with Robert McNeel & Associates.")
        about.present(self)

    def do_close_request(self):
        if self.proc is not None:
            self.toast("Please wait until this step finishes")
            return True
        return False


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.HANDLES_OPEN)

    def do_startup(self):
        Adw.Application.do_startup(self)
        # libadwaita's look is designed around the Adwaita icons; other themes
        # often lack the symbolic icons this app uses.
        if any(os.path.isdir(os.path.join(d, "icons/Adwaita")) for d in GLib.get_system_data_dirs()):
            Gtk.Settings.get_default().set_property("gtk-icon-theme-name", "Adwaita")

    def do_activate(self):
        if not self.props.active_window and installed_versions():
            refresh_menu_entries()
        win = self.props.active_window or Window(self)
        win.present()

    def do_open(self, files, n_files, hint):
        """A plug-in file opened from the file manager: install it."""
        self.activate()
        if files:
            self.props.active_window.install_plugin(files[0].get_path())


if __name__ == "__main__":
    sys.exit(App().run(sys.argv))
