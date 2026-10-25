#!/usr/bin/env python3
"""Print the Vulkan graphics devices, one per line: "<type>\t<name>".

    list-gpus.py      ->  gpu    NVIDIA GeForce RTX 4080 SUPER
                          gpu    Intel(R) Graphics (ARL)
                          cpu    llvmpipe (LLVM 19.1.7, 256 bits)

The names are the ones DXVK matches DXVK_FILTER_DEVICE_NAME against. Asks
libvulkan directly, with only Python's standard library, because the Flatpak
has no vulkaninfo. Exits 1 when Vulkan is missing or has no device.
"""
import ctypes
import sys

VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
VK_API_VERSION_1_0 = 1 << 22
VK_PHYSICAL_DEVICE_TYPE_CPU = 4


class ApplicationInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_int), ("pNext", ctypes.c_void_p),
                ("pApplicationName", ctypes.c_char_p), ("applicationVersion", ctypes.c_uint32),
                ("pEngineName", ctypes.c_char_p), ("engineVersion", ctypes.c_uint32),
                ("apiVersion", ctypes.c_uint32)]


class InstanceCreateInfo(ctypes.Structure):
    _fields_ = [("sType", ctypes.c_int), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32),
                ("pApplicationInfo", ctypes.POINTER(ApplicationInfo)),
                ("enabledLayerCount", ctypes.c_uint32), ("ppEnabledLayerNames", ctypes.c_void_p),
                ("enabledExtensionCount", ctypes.c_uint32), ("ppEnabledExtensionNames", ctypes.c_void_p)]


def devices():
    vk = ctypes.CDLL("libvulkan.so.1")
    vk.vkCreateInstance.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
    vk.vkEnumeratePhysicalDevices.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
    vk.vkGetPhysicalDeviceProperties.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    vk.vkDestroyInstance.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    app = ApplicationInfo(VK_STRUCTURE_TYPE_APPLICATION_INFO, None, b"Rhino on Linux", 1, None, 0, VK_API_VERSION_1_0)
    info = InstanceCreateInfo(VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, None, 0, ctypes.pointer(app), 0, None, 0, None)
    instance = ctypes.c_void_p()
    if vk.vkCreateInstance(ctypes.byref(info), None, ctypes.byref(instance)) != 0:
        return []
    try:
        count = ctypes.c_uint32()
        vk.vkEnumeratePhysicalDevices(instance, ctypes.byref(count), None)
        handles = (ctypes.c_void_p * count.value)()
        vk.vkEnumeratePhysicalDevices(instance, ctypes.byref(count), handles)
        found = []
        for handle in handles[:count.value]:
            # VkPhysicalDeviceProperties: 4 uint32s, deviceType, then deviceName[256]
            props = ctypes.create_string_buffer(4096)
            vk.vkGetPhysicalDeviceProperties(handle, props)
            kind = int.from_bytes(props.raw[16:20], "little")
            name = props.raw[20:276].split(b"\0", 1)[0].decode(errors="replace").strip()
            found.append(("cpu" if kind == VK_PHYSICAL_DEVICE_TYPE_CPU else "gpu", name))
        return found
    finally:
        vk.vkDestroyInstance(instance, None)


def main():
    try:
        found = devices()
    except (OSError, AttributeError):
        found = []
    # The Flatpak can list a card once per driver manifest; show each card once.
    for kind, name in dict.fromkeys(found):
        print(f"{kind}\t{name}")
    sys.exit(0 if found else 1)


if __name__ == "__main__":
    main()
