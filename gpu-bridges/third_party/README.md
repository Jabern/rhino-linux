# Third-party headers

- `hipew.h`: Cycles' HIP wrangler header, from [Cycles](https://github.com/blender/cycles)
  v4.0.0 (`third_party/hipew/include/hipew.h`), the Cycles of Rhino 8. Apache License 2.0,
  Blender Foundation.
- `ze_api.h`, `zes_api.h`: the [Level Zero](https://github.com/oneapi-src/level-zero) API
  headers, v1.17.0. MIT License, Intel Corporation.
- `hip_device_prop_r0600.h`: `hipDeviceProp_t` of HIP 6 and newer, from ROCm's
  [HIP](https://github.com/ROCm/HIP) rocm-6.4.0 `hip_runtime_api.h`. MIT License, Advanced
  Micro Devices. Rhino's Cycles has the older layout (`hipDeviceProp_tR0000`, as in McNeel's
  [Cycles](https://github.com/mcneel/cycles) `hipew.h`); the bridge translates when ROCm
  only has the new one.
