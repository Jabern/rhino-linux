/* Calls ze_loader.dll as Rhino's pi_level_zero.dll does and prints the results. */
#include <windows.h>
#include <stdio.h>
#define ZE_APIEXPORT
#include "../third_party/ze_api.h"
int main(void)
{
    HMODULE m = LoadLibraryA("ze_loader.dll");
    uint32_t count = 0;
    ze_driver_handle_t driver = NULL;
    ze_device_handle_t device = NULL;
    ze_device_properties_t props = {ZE_STRUCTURE_TYPE_DEVICE_PROPERTIES};
    ze_module_desc_t desc = {ZE_STRUCTURE_TYPE_MODULE_DESC, NULL, ZE_MODULE_FORMAT_IL_SPIRV, 1234, (const uint8_t *)"spv", "-ze-opt-level=2"};
    ze_module_handle_t module = NULL;
    void *ext = (void *)1;
    if (!m) { printf("ze_loader.dll not loaded (error %lu)\n", GetLastError()); return 1; }
#define F(n, ...) ze_result_t (__cdecl *n)(__VA_ARGS__) = (void *)GetProcAddress(m, #n)
    F(zeInit, ze_init_flags_t);
    F(zeDriverGet, uint32_t *, ze_driver_handle_t *);
    F(zeDeviceGet, ze_driver_handle_t, uint32_t *, ze_device_handle_t *);
    F(zeDeviceGetProperties, ze_device_handle_t, ze_device_properties_t *);
    F(zeModuleCreate, ze_context_handle_t, ze_device_handle_t, const ze_module_desc_t *, ze_module_handle_t *, ze_module_build_log_handle_t *);
    F(zeKernelSetGroupSize, ze_kernel_handle_t, uint32_t, uint32_t, uint32_t);
    F(zeDriverGetExtensionFunctionAddress, ze_driver_handle_t, const char *, void **);
    printf("zeInit -> %#x\n", zeInit(ZE_INIT_FLAG_GPU_ONLY));
    {
        ze_result_t r = zeDriverGet(&count, NULL);
        printf("zeDriverGet -> %#x, count %u\n", r, count);
    }
    if (!count) return 0;
    count = 1; zeDriverGet(&count, &driver);
    count = 1; zeDeviceGet(driver, &count, &device);
    ze_result_t r = zeDeviceGetProperties(device, &props);
    printf("zeDeviceGetProperties -> %#x: '%s', id %#x, EUs/subslice %u, max alloc %llu\n",
           r, props.name, props.deviceId, props.numEUsPerSubslice,
           (unsigned long long)props.maxMemAllocSize);
    r = zeModuleCreate((void *)0x7, device, &desc, &module, NULL);
    printf("zeModuleCreate -> %#x, module %p\n", r, (void *)module);
    printf("zeKernelSetGroupSize -> %#x\n", zeKernelSetGroupSize((void *)0x9, 8, 4, 2));
    r = zeDriverGetExtensionFunctionAddress(driver, "zexDriverImportExternalPointer", &ext);
    printf("zeDriverGetExtensionFunctionAddress -> %#x, %p\n", r, ext);
    return 0;
}
