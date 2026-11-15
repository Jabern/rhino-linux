/* A stand-in for a ROCm without hipGetDevicePropertiesR0000: only the HIP 6 layout. */
#include <stdio.h>
#include <string.h>
#define hipInit hipew_hipInit /* hipew.h declares the loader's pointers by these names */
#include "../third_party/hipew.h"
#undef hipInit
#include "../third_party/hip_device_prop_r0600.h"
int hipInit(unsigned int flags) { return 0; }
int hipGetDevicePropertiesR0600(hipDeviceProp_tR0600 *p, int dev)
{
    strcpy(p->name, "Fake Radeon RX 7900 XTX");
    strcpy(p->gcnArchName, "gfx1100:sramecc-:xnack-");
    p->totalGlobalMem = 24ull << 30; p->multiProcessorCount = 96; p->major = 11; p->pciBusID = 3;
    return 0;
}
