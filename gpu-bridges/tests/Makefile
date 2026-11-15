# Stand-ins for the Linux libraries and Windows test programs, to check the bridges
# without the hardware (see ../README.md). Run the .exe files with the bridges built:
#   cp ../amdhip64/amdhip64_6.dll.so amdhip64_6.dll; cp ../ze_loader/ze_loader.dll.so ze_loader.dll
#   LD_LIBRARY_PATH=$PWD wine hiptest.exe           (ROCm with hipGetDevicePropertiesR0000)
#   LD_LIBRARY_PATH=$PWD/r0600 wine propstest.exe   (ROCm with only hipGetDevicePropertiesR0600)
#   LD_LIBRARY_PATH=$PWD wine zetest.exe
CC ?= gcc
MINGW_CC ?= x86_64-w64-mingw32-gcc

all: libamdhip64.so.6 r0600/libamdhip64.so.6 libze_loader.so.1 hiptest.exe propstest.exe zetest.exe

libamdhip64.so.6: fake_libamdhip64.c
	$(CC) -shared -fPIC -o $@ $<

r0600/libamdhip64.so.6: fake_libamdhip64_r0600.c
	mkdir -p r0600
	$(CC) -shared -fPIC -o $@ $<

libze_loader.so.1: fake_libze_loader.c
	$(CC) -shared -fPIC -o $@ $<

%.exe: %.c
	$(MINGW_CC) -std=gnu17 -o $@ $<

clean:
	rm -rf *.so.* r0600 *.exe *.dll

.PHONY: all clean
