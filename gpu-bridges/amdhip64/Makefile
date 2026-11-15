# amdhip64_6.dll for Wine (a builtin ELF library, like nvidia-libs' nvcuda.dll).
# WINE_BUILD: a Wine build tree (for winegcc, winebuild and its include/); WINE_SRC its source.
WINE_BUILD ?= ../../build-wine
WINE_SRC ?= $(WINE_BUILD)/../wine-src
WINEGCC = $(WINE_BUILD)/tools/winegcc/winegcc -b x86_64-linux-gnu \
          -B$(WINE_BUILD)/tools/winebuild --winebuild $(WINE_BUILD)/tools/winebuild/winebuild \
          -I$(WINE_BUILD)/include -I$(WINE_SRC)/include
CFLAGS ?= -O2 -g -Wall

all: amdhip64_6.dll.so

amdhip64_6_thunks.c amdhip64_6.spec: gen_amdhip64.py hip-functions.txt ../third_party/hipew.h
	python3 gen_amdhip64.py

amdhip64_6.dll.so: amdhip64_6.spec amdhip64_main.c amdhip64_6_thunks.c amdhip64_private.h
	$(WINEGCC) $(CFLAGS) -shared amdhip64_6.spec amdhip64_main.c amdhip64_6_thunks.c \
	    -o amdhip64_6.dll -ldl -lkernel32

clean:
	rm -f amdhip64_6.dll.so

.PHONY: all clean
