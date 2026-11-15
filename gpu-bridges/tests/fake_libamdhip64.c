/* A stand-in for ROCm's libamdhip64.so.6, to test amdhip64_6.dll without an AMD GPU:
 * one fake device, and every call reports what it received on stderr. */
#include <stdio.h>
#include <string.h>
typedef struct { unsigned int x, y, z; } dim3;
int hipInit(unsigned int flags) { fprintf(stderr, "fake hipInit(%u)\n", flags); return 0; }
int hipGetDeviceCount(int *count) { *count = 1; return 0; }
int hipDeviceGetName(char *name, int len, int dev) { snprintf(name, len, "Fake Radeon %d", dev); return 0; }
int hipDeviceGetAttribute(int *value, int attr, int dev) { *value = attr * 10 + dev; return 0; }
int hipGetDevicePropertiesR0000(char *props, int dev) { strcpy(props, "R0000 layout"); return 0; }
int hipModuleLoad(void **module, const char *fname) { fprintf(stderr, "fake hipModuleLoad(%s)\n", fname); *module = (void *)0x1234; return 0; }
int hipConfigureCall(dim3 grid, dim3 block, size_t shared, void *stream)
{ fprintf(stderr, "fake hipConfigureCall(%u,%u,%u / %u,%u,%u / %zu / %p)\n", grid.x, grid.y, grid.z, block.x, block.y, block.z, shared, stream); return 0; }
int hipModuleLaunchKernel(void *f, unsigned gx, unsigned gy, unsigned gz, unsigned bx, unsigned by, unsigned bz,
                          unsigned shared, void *stream, void **params, void **extra)
{ fprintf(stderr, "fake hipModuleLaunchKernel(%p, %u %u %u, %u %u %u, %u, %p, %p, %p)\n", f, gx, gy, gz, bx, by, bz, shared, stream, params, extra); return 0; }
