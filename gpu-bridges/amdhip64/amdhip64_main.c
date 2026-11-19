/*
 * amdhip64_6.dll for Wine: loading ROCm's libamdhip64.so, and path conversion.
 */
#include <dlfcn.h>
#include <stdio.h>
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

/* The HIP runtime rhino-linux downloads (gpu-bridges/hip-runtime), when RHINO_HIP_RUNTIME
 * names its folder: tried before the system's ROCm, as the version checked with Cycles.
 * Its lib/fallback has the libraries the Flatpak runtime lacks; loaded only when the
 * system has none, so the graphics drivers keep their own libdrm_amdgpu. */
static void *load_bundled_hip(void)
{
    static const char * const deps[] = { "libnuma.so.1", "libdrm_amdgpu.so.1" };
    const char *dir = getenv( "RHINO_HIP_RUNTIME" );
    char path[4096];
    unsigned int i;
    void *lib;

    if (!dir || !*dir) return NULL;
    for (i = 0; i < ARRAY_SIZE(deps); i++)
    {
        if (dlopen( deps[i], RTLD_NOW | RTLD_GLOBAL )) continue;
        snprintf( path, sizeof(path), "%s/lib/fallback/%s", dir, deps[i] );
        if (!dlopen( path, RTLD_NOW | RTLD_GLOBAL )) WINE_WARN( "%s: %s\n", path, dlerror() );
    }
    snprintf( path, sizeof(path), "%s/lib/libamdhip64.so.6", dir );
    if (!(lib = dlopen( path, RTLD_NOW ))) WINE_WARN( "%s: %s\n", path, dlerror() );
    else WINE_TRACE( "using %s\n", path );
    return lib;
}

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
        hip_lib = load_bundled_hip();
        for (i = 0; i < ARRAY_SIZE(libraries) && !hip_lib; i++)
            hip_lib = dlopen( libraries[i], RTLD_NOW );
        /* Without ROCm, still load, and report no device: every call fails, hipInit with
         * hipErrorNoDevice, and Cycles lists no HIP device. Failing DllMain instead hung
         * Rhino's start, the loader lock taken by a thread that never let it go. */
        if (hip_lib)
        {
            load_functions( hip_lib );
            load_props_functions( hip_lib );
        }
        else WINE_WARN( "no libamdhip64.so.6 or .so.7 (ROCm's HIP runtime) found\n" );
        DisableThreadLibraryCalls( instance );
        break;
    case DLL_PROCESS_DETACH:
        if (reserved || !hip_lib) break;
        dlclose( hip_lib );
        break;
    }
    return TRUE;
}
