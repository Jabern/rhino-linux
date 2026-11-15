/* Reads hipGetDeviceProperties through Cycles' own hipDeviceProp_t (hipew.h), as Cycles
 * does to pick kernel_<gfx arch>.fatbin. */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include "../third_party/hipew.h"
int main(void)
{
    HMODULE m = LoadLibraryA("amdhip64_6.dll");
    hipDeviceProp_t props;
    hipError_t (*getprops)(hipDeviceProp_t *, int) = (void *)GetProcAddress(m, "hipGetDeviceProperties");
    hipError_t ret;
    memset(&props, 0xcc, sizeof(props));
    ret = getprops(&props, 0);
    printf("hipGetDeviceProperties -> %d: name '%s', gcnArchName '%s' (arch '%s'), %zu GB, %d CUs, %d.%d, bus %d\n",
           ret, props.name, props.gcnArchName, strtok(props.gcnArchName, ":"), props.totalGlobalMem >> 30,
           props.multiProcessorCount, props.major, props.minor, props.pciBusID);
    return 0;
}
