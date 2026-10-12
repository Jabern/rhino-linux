/* Exits 0 when DirectWrite's system font collection contains Tahoma.
 * WebView2 (Rhino's sign-in) builds its UI font from Tahoma through DirectWrite;
 * without it the browser crashes in an endless system-font loop.
 * Build: x86_64-w64-mingw32-gcc -O2 -o dwrite-tahoma.exe dwrite-tahoma.c -ldwrite */
#define COBJMACROS
#include <windows.h>
#include <dwrite.h>
#include <stdio.h>

static const GUID factory_iid = {0xb859ee5a, 0xd838, 0x4b5b, {0xa2, 0xe8, 0x1a, 0xdc, 0x7d, 0x93, 0xdb, 0x48}};

int main(void)
{
    IDWriteFontCollection *collection;
    IDWriteFactory *factory;
    BOOL exists = FALSE;
    UINT32 index;

    if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &factory_iid, (IUnknown **)&factory))) return 2;
    if (FAILED(IDWriteFactory_GetSystemFontCollection(factory, &collection, FALSE))) return 3;
    IDWriteFontCollection_FindFamilyName(collection, L"Tahoma", &index, &exists);
    printf("DirectWrite finds Tahoma: %s\n", exists ? "yes" : "no");
    return exists ? 0 : 1;
}
