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
        /* Without it, fail to load: SYCL then finds no Level Zero devices and Cycles lists
         * no oneAPI device, as on Windows without Intel's GPU driver. */
        if (!(ze_lib = dlopen( "libze_loader.so.1", RTLD_NOW )))
        {
            WINE_WARN( "no libze_loader.so.1 (Level Zero loader) found\n" );
            return FALSE;
        }
        load_functions( ze_lib );
        DisableThreadLibraryCalls( instance );
        break;
    case DLL_PROCESS_DETACH:
        if (reserved) break;
        dlclose( ze_lib );
        break;
    }
    return TRUE;
}
