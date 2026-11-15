/*
 * amdhip64_6.dll for Wine: Cycles' HIP calls passed on to ROCm's libamdhip64.so.
 *
 * Built as a Wine builtin ELF library (like nvidia-libs' nvcuda.dll): the exports use the
 * Windows calling convention (WINAPI), the function pointers into libamdhip64.so the
 * Linux one, and gcc converts between them, also for structs passed by value (dim3).
 * HIP's types have the same layout on both sides: hipew.h uses no plain "long".
 */
#ifndef __AMDHIP64_PRIVATE_H
#define __AMDHIP64_PRIVATE_H

#include <dlfcn.h>
#include <stdarg.h>
#include <stddef.h>

#include "windef.h"
#include "winbase.h"
#include "winnls.h"
#include "wine/debug.h"

#include "../third_party/hipew.h"

WINE_DEFAULT_DEBUG_CHANNEL(amdhip64);

#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))

/* hipConfigureCall's launch dimensions, as in hip_runtime_api.h (not in hipew.h) */
typedef struct dim3
{
    unsigned int x, y, z;
} dim3;

char *unix_path( const char *dos_path );
void free_unix_path( char *path );
void load_functions( void *lib );
void load_props_functions( void *lib );
hipError_t get_props_from_r0600( hipDeviceProp_t *prop, int device );

#define LOAD(name, ...) \
    do { \
        static const char * const syms[] = {__VA_ARGS__}; \
        unsigned int i; \
        for (i = 0; i < ARRAY_SIZE(syms) && !p_##name; i++) p_##name = dlsym( lib, syms[i] ); \
        if (!p_##name) WINE_WARN( "%s not found in libamdhip64\n", #name ); \
    } while (0)

#endif
