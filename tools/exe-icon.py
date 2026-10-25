#!/usr/bin/env python3
"""Save the main icon of a Windows .exe as a PNG.

    exe-icon.py Rhino.exe rhino8.png      prints the icon's size, e.g. "256"

Reads the PE resources directly, so it needs nothing outside Python's standard
library for PNG icons (Rhino's 256 px icons are PNG); older bitmap icons are
converted with GdkPixbuf when it is available. Exits 1 when no icon is found.
"""
import struct
import sys

RT_ICON = 3
RT_GROUP_ICON = 14


class PE:
    def __init__(self, data):
        self.data = data
        pe = struct.unpack_from("<I", data, 0x3C)[0]
        if data[pe:pe + 4] != b"PE\0\0":
            raise ValueError("not a PE file")
        sections, opt_size = struct.unpack_from("<H12xH", data, pe + 6)
        opt = pe + 24
        magic = struct.unpack_from("<H", data, opt)[0]
        dirs = opt + (112 if magic == 0x20B else 96)
        self.rsrc_rva = struct.unpack_from("<I", data, dirs + 2 * 8)[0]
        self.sections = []
        for i in range(sections):
            s = opt + opt_size + 40 * i
            vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", data, s + 8)
            self.sections.append((vaddr, max(vsize, rawsize), rawptr))

    def offset(self, rva):
        for vaddr, size, rawptr in self.sections:
            if vaddr <= rva < vaddr + size:
                return rva - vaddr + rawptr
        raise ValueError("RVA outside every section")

    def entries(self, dir_off):
        """(id or None for named, offset relative to the resource root, is_dir)"""
        base = self.offset(self.rsrc_rva)
        named, ids = struct.unpack_from("<HH", self.data, base + dir_off + 12)
        for i in range(named + ids):
            name, target = struct.unpack_from("<II", self.data, base + dir_off + 16 + 8 * i)
            ident = None if name & 0x80000000 else name
            yield ident, target & 0x7FFFFFFF, bool(target & 0x80000000)

    def resources(self, rtype):
        """{id: bytes} of one resource type, first language of each."""
        base = self.offset(self.rsrc_rva)
        found = {}
        for ident, off, is_dir in self.entries(0):
            if ident != rtype or not is_dir:
                continue
            for name, name_off, name_is_dir in self.entries(off):
                leaf = name_off
                while name_is_dir:
                    _, leaf, name_is_dir = next(iter(self.entries(leaf)))
                rva, size = struct.unpack_from("<II", self.data, base + leaf)
                start = self.offset(rva)
                found.setdefault(name, self.data[start:start + size])
        return found


def main_icon(path):
    with open(path, "rb") as f:
        pe = PE(f.read())
    groups = pe.resources(RT_GROUP_ICON)
    icons = pe.resources(RT_ICON)
    if not groups:
        return None, 0
    # Explorer shows the first group; named groups sort before numbered ones.
    group = groups[min(groups, key=lambda k: (k is not None, k or 0))]
    count = struct.unpack_from("<H", group, 4)[0]
    best = None
    for i in range(count):
        w, h, colors, _, planes, bits, size, ident = struct.unpack_from("<BBBBHHIH", group, 6 + 14 * i)
        w = w or 256
        key = (w, bits)
        if ident in icons and (best is None or key > best[0]):
            best = (key, ident, (w, h, colors, planes, bits))
    if best is None:
        return None, 0
    (w, _), ident, entry = best
    data = icons[ident]
    if data.startswith(b"\x89PNG"):
        return data, w
    # A bitmap icon: wrap it in a one-image .ico and let GdkPixbuf convert it.
    w8, h8, colors, planes, bits = entry
    ico = struct.pack("<HHH", 0, 1, 1)
    ico += struct.pack("<BBBBHHII", w8 & 0xFF, h8, colors, 0, planes, bits, len(data), 22)
    ico += data
    try:
        import gi
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
        loader = GdkPixbuf.PixbufLoader.new_with_type("ico")
        loader.write(ico)
        loader.close()
        ok, png = loader.get_pixbuf().save_to_bufferv("png", [], [])
        return (bytes(png), w) if ok else (None, 0)
    except Exception:  # no GdkPixbuf, or it cannot read this icon
        return None, 0


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__.strip().splitlines()[2].strip())
    try:
        png, size = main_icon(sys.argv[1])
    except (OSError, ValueError, struct.error) as e:
        sys.exit(f"{sys.argv[1]}: {e}")
    if not png:
        sys.exit(f"{sys.argv[1]}: no icon found")
    with open(sys.argv[2], "wb") as f:
        f.write(png)
    print(size)


if __name__ == "__main__":
    main()
