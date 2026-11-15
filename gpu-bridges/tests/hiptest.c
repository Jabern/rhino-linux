/* Calls amdhip64_6.dll as Cycles does (LoadLibrary + GetProcAddress) and prints the results. */
#include <windows.h>
#include <stdio.h>
typedef struct { unsigned int x, y, z; } dim3;
int main(void)
{
    HMODULE m = LoadLibraryA("amdhip64_6.dll");
    char name[64] = "", props[2048] = "";
    int count = -1, value = -1, ret;
    void *module = NULL;
    dim3 g = {1, 2, 3}, b = {4, 5, 6};
    if (!m) { printf("amdhip64_6.dll not loaded (error %lu)\n", GetLastError()); return 1; }
#define F(n) int (*n)() = (void *)GetProcAddress(m, #n)
    F(hipInit); F(hipGetDeviceCount); F(hipDeviceGetName); F(hipDeviceGetAttribute);
    F(hipGetDeviceProperties); F(hipModuleLoad); F(hipConfigureCall); F(hipModuleLaunchKernel);
    F(hipGraphicsGLRegisterBuffer);
    printf("hipInit -> %d\n", hipInit(0));
    ret = hipGetDeviceCount(&count);
    printf("hipGetDeviceCount -> %d, count %d\n", ret, count);
    printf("hipDeviceGetName -> %d, '%s'\n", hipDeviceGetName(name, (int)sizeof(name), 0), name);
    ret = hipDeviceGetAttribute(&value, 7, 0);
    printf("hipDeviceGetAttribute -> %d, %d\n", ret, value);
    printf("hipGetDeviceProperties -> %d, '%s'\n", hipGetDeviceProperties(props, 0), props);
    ret = ((int (*)(void **, const char *))hipModuleLoad)(&module, "C:\\windows\\system32\\kernel_gfx1100.fatbin");
    printf("hipModuleLoad -> %d, module %p\n", ret, module);
    printf("hipConfigureCall -> %d\n", ((int (*)(dim3, dim3, size_t, void *))hipConfigureCall)(g, b, 77, (void *)0x55));
    printf("hipModuleLaunchKernel -> %d\n", ((int (*)(void *, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, void *, void **, void **))
           hipModuleLaunchKernel)((void *)0x99, 1, 2, 3, 4, 5, 6, 7, (void *)0x8, (void **)0x9, (void **)0xa));
    printf("hipGraphicsGLRegisterBuffer -> %d (801 = not supported)\n", hipGraphicsGLRegisterBuffer(NULL, 1, 0));
    return 0;
}
