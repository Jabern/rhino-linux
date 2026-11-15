/*
 * ze_loader.dll for Wine: loading the Linux Level Zero loader.
 */
#include "ze_loader_private.h"

static void *ze_lib;

BOOL WINAPI DllMain( HINSTANCE instance, DWORD reason, void *reserved )
{
    switch (reason)
    {
    case DLL_PROCESS_ATTACH:
        /* Without it, still load, and report no driver: zeInit fails, SYCL finds no Level
         * Zero device and Cycles lists no oneAPI device, as on Windows without Intel's GPU
         * driver. Failing DllMain instead can hang the process in the loader. */
        if ((ze_lib = dlopen( "libze_loader.so.1", RTLD_NOW ))) load_functions( ze_lib );
        else WINE_WARN( "no libze_loader.so.1 (Level Zero loader) found\n" );
        DisableThreadLibraryCalls( instance );
        break;
    case DLL_PROCESS_DETACH:
        if (reserved || !ze_lib) break;
        dlclose( ze_lib );
        break;
    }
    return TRUE;
}
