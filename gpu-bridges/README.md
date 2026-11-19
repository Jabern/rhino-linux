# GPU bridges for Rhino's Cycles

Rhino's Cycles renders on AMD GPUs through HIP and on Intel GPUs through oneAPI. On
Windows it loads AMD's `amdhip64_6.dll` and, for Intel, its own SYCL runtime over
`ze_loader.dll`. Under Wine these come from here instead, and pass the calls on to the
Linux drivers, as [nvidia-libs](https://github.com/SveSop/nvidia-libs) does for CUDA:

| Bridge | Rhino loads | Passed on to (Linux) | Needs |
|---|---|---|---|
| `amdhip64/` | `amdhip64_6.dll` | `libamdhip64.so.6` (or `.7`) | an AMD GPU Cycles supports (Vega and newer) and a HIP runtime: the one in `hip-runtime/`, or the system's ROCm |
| `ze_loader/` | `ze_loader.dll` (instead of Rhino's own) | `libze_loader.so.1` | an Intel Arc (Xe-HPG or newer) GPU, the Level Zero loader and Intel's compute runtime |

Both are Wine builtin libraries in ELF form, generated from the API headers in
`third_party/` (Cycles 4.0's `hipew.h`, Level Zero 1.17's headers) for exactly the
functions Rhino 8 uses (`hip-functions.txt`, `ze-functions.txt`). Calls that cannot work
through Wine report "not supported", and Cycles goes on without them: OpenGL interop
(the Raytraced viewport copies its frames instead), HIP stream callbacks, Level Zero
extensions and loader tracing. Without the Linux runtime, a bridge still loads and
reports no device (`hipInit`, `zeInit` fail), and Cycles lists no device of that kind, as
on Windows without the vendor's driver. (Failing to load instead hung Rhino at start.)

The runtime build (`.github/workflows/build-wine.yml`) builds them with Wine and ships
them in `lib/wine/rhino-bridges/`; `tools/rhino-linux` turns each one on when it finds
the GPU and the Linux runtime it needs. Wine only looks for a builtin library there when
a file of that name exists, as Rhino's own `ze_loader.dll` does; `amdhip64_6.dll` has none,
so the launcher copies the bridge into the prefix's `system32` (and removes it when AMD
rendering is off).

## The HIP runtime (`hip-runtime/`)

Few systems have ROCm (SteamOS and the Flatpak don't), so for an AMD GPU Rhino's Cycles
has kernels for (`Plug-ins/RhinoCycles/lib/kernel_gfxNNNN.fatbin`, matched against the
GPUs amdgpu's KFD lists), `tools/rhino-hip.sh` downloads AMD's HIP runtime, on unless
`RHINO_HIP=0`. `make-hip-runtime.sh` builds it from pinned AMD ROCm 6.4.4 packages for
Ubuntu 24.04 (HIP, ROCr, comgr, rocprofiler-register; about 45 MB) and the same bytes
anywhere, so the checksum `rhino-hip.sh` pins can be checked by
`.github/workflows/hip-runtime.yml`, which publishes it as the `hip-runtime-6.4.4`
release. `lib/fallback/` has libnuma and libdrm_amdgpu, which the Flatpak runtime lacks:
the bridge loads them only when the system has none, so the graphics drivers keep their
own libdrm_amdgpu, then the bundled `libamdhip64.so.6` (folder in `RHINO_HIP_RUNTIME`)
before any system ROCm.

Build by hand against a Wine build tree:

```bash
make -C amdhip64 WINE_BUILD=../../build-wine
make -C ze_loader WINE_BUILD=../../build-wine
```

`tests/` has stand-ins for `libamdhip64.so.6` and `libze_loader.so.1` and Windows test
programs, to check the bridges without the hardware.
