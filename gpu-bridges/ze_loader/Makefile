# ze_loader.dll for Wine (a builtin ELF library, like ../amdhip64).
# WINE_BUILD: a Wine build tree (for winegcc, winebuild and its include/); WINE_SRC its source.
WINE_BUILD ?= ../../build-wine
WINE_SRC ?= $(WINE_BUILD)/../wine-src
WINEGCC = $(WINE_BUILD)/tools/winegcc/winegcc -b x86_64-linux-gnu \
          -B$(WINE_BUILD)/tools/winebuild --winebuild $(WINE_BUILD)/tools/winebuild/winebuild \
          -I$(WINE_BUILD)/include -I$(WINE_SRC)/include
CFLAGS ?= -O2 -g -Wall

all: ze_loader.dll.so

ze_loader_thunks.c ze_loader.spec: gen_ze_loader.py ze-functions.txt ../third_party/ze_api.h ../third_party/zes_api.h
	python3 gen_ze_loader.py

ze_loader.dll.so: ze_loader.spec ze_loader_main.c ze_loader_thunks.c ze_loader_private.h
	$(WINEGCC) $(CFLAGS) -shared ze_loader.spec ze_loader_main.c ze_loader_thunks.c \
	    -o ze_loader.dll -ldl

clean:
	rm -f ze_loader.dll.so

.PHONY: all clean
