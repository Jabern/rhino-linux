/*
 * amdhip64_6.dll for Wine: loading ROCm's libamdhip64.so, and path conversion.
 */
#include <dlfcn.h>
#include <stdlib.h>

#include "amdhip64_private.h"

/* Where ROCm puts its HIP runtime, by distribution package or AMD's installer. Cycles was
 * built against HIP 6; ROCm 7 keeps the calls it uses. */
static const char * const libraries[] =
{
    "libamdhip64.so.6",
    "/opt/rocm/lib/libamdhip64.so.6",
    "libamdhip64.so.7",
    "/opt/rocm/lib/libamdhip64.so.7",
};

static void *hip_lib;

char * CDECL wine_get_unix_file_name( const WCHAR *dos );

char *unix_path( const char *dos_path )
{
    WCHAR *dos;
    char *ret;
    int len;

    if (!dos_path) return NULL;
    len = MultiByteToWideChar( CP_ACP, 0, dos_path, -1, NULL, 0 );
    if (!(dos = HeapAlloc( GetProcessHeap(), 0, len * sizeof(WCHAR) ))) return NULL;
    MultiByteToWideChar( CP_ACP, 0, dos_path, -1, dos, len );
    ret = wine_get_unix_file_name( dos );
    HeapFree( GetProcessHeap(), 0, dos );
    WINE_TRACE( "%s -> %s\n", wine_dbgstr_a(dos_path), wine_dbgstr_a(ret) );
    return ret;
}

void free_unix_path( char *path )
{
    HeapFree( GetProcessHeap(), 0, path );
}

BOOL WINAPI DllMain( HINSTANCE instance, DWORD reason, void *reserved )
{
    unsigned int i;

    switch (reason)
    {
    case DLL_PROCESS_ATTACH:
        for (i = 0; i < ARRAY_SIZE(libraries) && !hip_lib; i++)
            hip_lib = dlopen( libraries[i], RTLD_NOW );
        /* Without ROCm, fail to load as amdhip64_6.dll does without AMD's driver on
         * Windows: Cycles then lists no HIP device. */
        if (!hip_lib)
        {
            WINE_WARN( "no libamdhip64.so.6 or .so.7 (ROCm's HIP runtime) found\n" );
            return FALSE;
        }
        load_functions( hip_lib );
        DisableThreadLibraryCalls( instance );
        break;
    case DLL_PROCESS_DETACH:
        if (reserved) break;
        dlclose( hip_lib );
        break;
    }
    return TRUE;
}
