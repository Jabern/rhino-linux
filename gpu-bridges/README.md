# GPU bridges for Rhino's Cycles

Rhino's Cycles renders on AMD GPUs through HIP and on Intel GPUs through oneAPI. On
Windows it loads AMD's `amdhip64_6.dll` and, for Intel, its own SYCL runtime over
`ze_loader.dll`. Under Wine these come from here instead, and pass the calls on to the
Linux drivers, as [nvidia-libs](https://github.com/SveSop/nvidia-libs) does for CUDA:

| Bridge | Rhino loads | Passed on to (Linux) | Needs |
|---|---|---|---|
| `amdhip64/` | `amdhip64_6.dll` | `libamdhip64.so.6` (or `.7`) | an AMD GPU Cycles supports (Vega and newer) and ROCm's HIP runtime |
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
the GPU and the Linux runtime it needs.

Build by hand against a Wine build tree:

```bash
make -C amdhip64 WINE_BUILD=../../build-wine
make -C ze_loader WINE_BUILD=../../build-wine
```

`tests/` has stand-ins for `libamdhip64.so.6` and `libze_loader.so.1` and Windows test
programs, to check the bridges without the hardware.
