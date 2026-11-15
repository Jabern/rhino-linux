# amdhip64_6.dll for Wine (a builtin ELF library, like nvidia-libs' nvcuda.dll).
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

all: amdhip64_6.dll.so

amdhip64_6_thunks.c amdhip64_6.spec: gen_amdhip64.py hip-functions.txt ../third_party/hipew.h
	python3 gen_amdhip64.py

amdhip64_6.dll.so: amdhip64_6.spec amdhip64_main.c amdhip64_6_thunks.c amdhip64_private.h
	$(MAKE) -C $(WINE_BUILD) $(WINELIB_FILES)
	$(WINEGCC) $(CFLAGS) -shared amdhip64_6.spec amdhip64_main.c amdhip64_6_thunks.c \
	    -o amdhip64_6.dll -ldl $(WINELIBS)

clean:
	rm -f amdhip64_6.dll.so

.PHONY: all clean
