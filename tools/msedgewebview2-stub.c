/*
 * Microsoft Edge WebView2 Process Stub
 *
 * Minimal dummy process used when Edge WebView2 runtime is disabled.
 * Returns immediately with exit code 1 to indicate fallback to system browser.
 *
 * Compilation:
 *   x86_64-w64-mingw32-gcc -O2 -s -mwindows -o msedgewebview2-stub.exe msedgewebview2-stub.c
 */

#include <windows.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    return 1;
}
