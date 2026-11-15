/* A stand-in for libze_loader.so.1, to test ze_loader.dll without an Intel GPU: one fake
 * driver and device; calls report what they received on stderr. */
#include <stdio.h>
#include <string.h>
#include "../third_party/ze_api.h"
ze_result_t zeInit(ze_init_flags_t flags) { fprintf(stderr, "fake zeInit(%#x)\n", flags); return ZE_RESULT_SUCCESS; }
ze_result_t zeDriverGet(uint32_t *count, ze_driver_handle_t *drivers)
{ if (drivers && *count) drivers[0] = (ze_driver_handle_t)0x1111; *count = 1; return ZE_RESULT_SUCCESS; }
ze_result_t zeDeviceGet(ze_driver_handle_t d, uint32_t *count, ze_device_handle_t *devs)
{ if (devs && *count) devs[0] = (ze_device_handle_t)0x2222; *count = 1; return ZE_RESULT_SUCCESS; }
ze_result_t zeDeviceGetProperties(ze_device_handle_t dev, ze_device_properties_t *p)
{
    fprintf(stderr, "fake zeDeviceGetProperties(%p, stype %#x, sizeof %zu)\n", (void *)dev, p->stype, sizeof(*p));
    p->type = ZE_DEVICE_TYPE_GPU; p->deviceId = 0x56a0; p->numEUsPerSubslice = 16; p->maxMemAllocSize = 1ull << 33;
    strcpy(p->name, "Fake Intel Arc A770");
    return ZE_RESULT_SUCCESS;
}
ze_result_t zeModuleCreate(ze_context_handle_t c, ze_device_handle_t d, const ze_module_desc_t *desc,
                           ze_module_handle_t *m, ze_module_build_log_handle_t *log)
{
    fprintf(stderr, "fake zeModuleCreate(format %d, %zu bytes, flags '%s')\n", desc->format, desc->inputSize, desc->pBuildFlags);
    *m = (ze_module_handle_t)0x3333; return ZE_RESULT_SUCCESS;
}
ze_result_t zeKernelSetGroupSize(ze_kernel_handle_t k, uint32_t x, uint32_t y, uint32_t z)
{ fprintf(stderr, "fake zeKernelSetGroupSize(%p, %u %u %u)\n", (void *)k, x, y, z); return ZE_RESULT_SUCCESS; }
