# ze_loader.dll for Wine (a builtin ELF library, like ../amdhip64).
# WINE_BUILD: a Wine build tree (for winegcc, winebuild and its include/); WINE_SRC its source.
WINE_BUILD ?= ../../build-wine
WINE_SRC ?= $(WINE_BUILD)/../wine-src
WINEGCC = $(WINE_BUILD)/tools/winegcc/winegcc -b x86_64-linux-gnu --wine-objdir $(WINE_BUILD) \
          -B$(WINE_BUILD)/tools/winebuild --winebuild $(WINE_BUILD)/tools/winebuild/winebuild \
          -I$(WINE_BUILD)/include -I$(WINE_SRC)/include
CFLAGS ?= -O2 -g -Wall
# Wine's Unix-side startup code and import libraries, from the build tree
WINELIBS = -L$(WINE_BUILD)/libs/winecrt0 -L$(WINE_BUILD)/dlls/kernel32 -L$(WINE_BUILD)/dlls/ntdll \
           -lwinecrt0 -lkernel32 -lntdll
# not part of Wine's default build: made on demand
WINELIB_FILES = libs/winecrt0/libwinecrt0.a dlls/kernel32/libkernel32.a dlls/ntdll/libntdll.a

all: ze_loader.dll.so

ze_loader_thunks.c ze_loader.spec: gen_ze_loader.py ze-functions.txt ../third_party/ze_api.h ../third_party/zes_api.h
	python3 gen_ze_loader.py

ze_loader.dll.so: ze_loader.spec ze_loader_main.c ze_loader_thunks.c ze_loader_private.h
	$(MAKE) -C $(WINE_BUILD) $(WINELIB_FILES)
	$(WINEGCC) $(CFLAGS) -shared ze_loader.spec ze_loader_main.c ze_loader_thunks.c \
	    -o ze_loader.dll -ldl $(WINELIBS)

clean:
	rm -f ze_loader.dll.so

.PHONY: all clean
