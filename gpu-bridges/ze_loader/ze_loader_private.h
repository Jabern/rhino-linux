/*
 * ze_loader.dll for Wine: Level Zero calls passed on to the Linux loader, libze_loader.so.1.
 *
 * Built as a Wine builtin ELF library, like ../amdhip64: the exports use the Windows
 * calling convention, the function pointers into libze_loader.so.1 the Linux one. Level
 * Zero's types have the same layout on both sides: its headers use no plain "long".
 */
#ifndef __ZE_LOADER_PRIVATE_H
#define __ZE_LOADER_PRIVATE_H

#include <dlfcn.h>
#include <stdarg.h>
#include <stddef.h>

#include "windef.h"
#include "winbase.h"
#include "wine/debug.h"

/* only the types: our exports are the wine_* functions in ze_loader.spec */
#define ZE_APIEXPORT
#include "../third_party/ze_api.h"
#include "../third_party/zes_api.h"

WINE_DEFAULT_DEBUG_CHANNEL(ze_loader);

void load_functions( void *lib );

#define LOAD(name) \
    do { \
        if (!(p_##name = dlsym( lib, #name ))) WINE_WARN( "%s not found in libze_loader\n", #name ); \
    } while (0)

#endif
