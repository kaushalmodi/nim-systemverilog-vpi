# Time-stamp: <2021-05-07 14:15:50 kmodi>
# Author    : Kaushal Modi

UVM ?= 0

FILES   ?= tb.sv
DEFINES	= DEFINE_PLACEHOLDER
# DSEM2009, DSEMEL: Don't keep on bugging by telling that SV 2009 is
#     being used. I know it already.
# SPDUSD: Don't warn about unused include dirs.
NOWARNS = -nowarn DSEM2009 -nowarn DSEMEL -nowarn SPDUSD
NC_SWITCHES ?=
NC_CLEAN ?= 1

# Subdirs contains a list of all directories containing a "Makefile".
SUBDIRS = $(shell find . -name "Makefile" | sed 's|/Makefile||')

GDB ?= 0 # When set to 1, enable gdb support for both nim and xrun
VALG ?= 0 # When set to 1, enable valgrind

NIM ?= nim

ARCH ?= 64
ifeq ($(ARCH), 64)
	NIM_ARCH_FLAGS :=
	NIM_SO := libvpi_64.so
	NC_ARCH_FLAGS := -64bit
	GCC_ARCH_FLAG := -m64
else
	NIM_ARCH_FLAGS := --cpu:i386 --passC:-m32 --passL:-m32
	NIM_SO := libvpi_32.so
	NC_ARCH_FLAGS :=
	GCC_ARCH_FLAG := -m32
endif

DEFAULT_VPI_LIB ?= libvpi.so
# Possible values of NIM_COMPILES_TO: c, cpp
NIM_COMPILES_TO ?= c
# See ./gc_crash_debug/README.org on why --gc:none is the default.
NIM_GC ?= none
NIM_RELEASE ?= 1
NIM_DEFINES ?=
NIM_SWITCHES ?=
NIM_THREADS ?= 0
NIM_DBG_DLL ?= 0

.PHONY: clean nim nimcpp clibvpi nc $(SUBDIRS) all valg

clean:
	rm -rf *~ core simv* urg* *.log *.history \#*.* *.dump .simvision/ waves.shm/ \
	  core.* simv* csrc* *.tmp *.vpd *.key log temp .vcs* DVE* *~ \
	  INCA_libs xcelium.d *.o ./.nimcache sigusrdump.out \
	  .bpad/ bpad*.err

# libvpi.nim -> libvpi.c -> $(DEFAULT_VPI_LIB)
# --gc:none is needed else Nim tries to free memory allocated for
# arrays and stuff by the simulator on SV side.
# https://irclogs.nim-lang.org/21-01-2019.html#17:16:39
# Thanks to https://stackoverflow.com/a/15561911/1219634 for the trick to
# modify Makefile vars within target definitions.
nim:
	@find . \( -name libvpi.o -o -name $(NIM_SO) \) -delete
ifeq ($(GDB), 1)
	$(eval NIM_SWITCHES += --debugger:native)
	$(eval NIM_SWITCHES += --listCmd)
	$(eval NIM_SWITCHES += --gcc.options.debug="-O0 -g3 -ggdb3")
	$(eval NIM_SWITCHES += --gcc.cpp.options.debug="-O0 -g3 -ggdb3")
endif
ifeq ($(NIM_THREADS), 1)
	$(eval NIM_SWITCHES += --threads:on)
endif
ifeq ($(NIM_RELEASE), 1)
	$(eval NIM_DEFINES += -d:release)
endif
ifeq ($(NIM_DBG_DLL), 1)
	$(eval NIM_DEFINES += -d:nimDebugDlOpen)
endif
ifeq ($(VALG), 1)
	$(eval NIM_DEFINES += -d:useSysAssert -d:useGcAssert)
endif
ifneq ($(NIM_GC),)
	$(eval NIM_SWITCHES += --gc:$(NIM_GC))
endif
	$(NIM) $(NIM_COMPILES_TO) --out:$(NIM_SO) --app:lib \
	  --nimcache:./.nimcache \
	  $(NIM_ARCH_FLAGS) $(NIM_DEFINES) \
	  $(NIM_SWITCHES) \
	  --hint[Processing]:off \
	  libvpi.nim

nimcpp:
	$(MAKE) nim NIM_COMPILES_TO=cpp

nc:
	ln -sf $(NIM_SO) $(DEFAULT_VPI_LIB)
ifeq ($(UVM), 1)
	$(eval NC_SWITCHES += -uvm -uvmhome CDNS-1.2)
endif
ifeq ($(GDB), 1)
	$(eval NC_SWITCHES += -g -gdb)
endif
ifeq ($(VALG), 1)
	$(eval NC_SWITCHES += -valgrind)
endif
ifeq ($(NC_CLEAN), 1)
	$(eval NC_SWITCHES += -clean)
endif
	xrun -sv $(NC_ARCH_FLAGS) \
	  -timescale 1ns/10ps \
	  +define+SHM_DUMP -debug \
	  +define+$(DEFINES) \
	  $(FILES) \
	  +incdir+./ \
	  $(NOWARNS) \
	  $(NC_SWITCHES)

# libvpi.c -> $(DEFAULT_SV_LIB)
# -I$(XCELIUM_ROOT)/../include for "vpi_user.h"
clibvpi:
	@find . \( -name libvpi.o -o -name $(NIM_SO) \) -delete
	gcc -c -fPIC -I$(XCELIUM_ROOT)/../include libvpi.c $(GCC_ARCH_FLAG) -o libvpi.o
	gcc -shared -Wl,-soname,$(DEFAULT_SV_LIB) $(GCC_ARCH_FLAG) -o $(NIM_SO) libvpi.o
	@rm -f libvpi.o

$(SUBDIRS):
	$(MAKE) -C $@

all: $(SUBDIRS)

# Run "make ARCH=32" to build 32-bit libvpi_32.so and run 32-bit xrun.
# Run "make" to build 64-bit libvpi_64.so and run 64-bit xrun.
