# Time-stamp: <2025-05-16 11:46:25 kmodi>
# Author    : Kaushal Modi

UVM ?= 0

LIB_BASENAME ?= libvpi

SV_FILES   ?= tb.sv
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

C_FILES ?= $(LIB_BASENAME).c

NIM ?= nim

ARCH ?= 64
ifeq ($(ARCH), 64)
	NIM_ARCH_FLAGS :=
	ARCH_SO := $(LIB_BASENAME)_64.so
	NC_ARCH_FLAGS := -64bit
	GCC_ARCH_FLAG := -m64
else
	NIM_ARCH_FLAGS := --cpu:i386 --passC:-m32 --passL:-m32
	ARCH_SO := $(LIB_BASENAME)_32.so
	NC_ARCH_FLAGS :=
	GCC_ARCH_FLAG := -m32
endif

DEFAULT_SO ?= $(LIB_BASENAME).so
# Possible values of NIM_COMPILES_TO: c, cpp
NIM_COMPILES_TO ?= cpp
NIM_MM ?=
NIM_RELEASE ?= 1
NIM_DEFINES ?=
NIM_SWITCHES ?=
NIM_THREADS ?= 0
NIM_DBG_DLL ?= 0

.PHONY: clean nim nimc nimcpp clib nc $(SUBDIRS) all valg

clean:
	rm -rf *~ core simv* urg* *.log *.history \#*.* *.dump .simvision/ waves.shm/ \
	  core.* simv* csrc* *.tmp *.vpd *.key log temp .vcs* DVE* *~ \
	  INCA_libs xcelium.d *.o ./.nimcache sigusrdump.out \
	  .bpad/ bpad*.err

clean2: clean
	rm -rf *.so

# $(LIB_BASENAME).nim -> $(LIB_BASENAME).c -> $(DEFAULT_SO)
# --gc:none is needed else Nim tries to free memory allocated for
# arrays and stuff by the simulator on SV side.
# https://irclogs.nim-lang.org/21-01-2019.html#17:16:39
# Thanks to https://stackoverflow.com/a/15561911/1219634 for the trick to
# modify Makefile vars within target definitions.
nim:
	@find . \( -name *.o -o -name $(ARCH_SO) \) -delete
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
ifneq ($(NIM_MM),)
	$(eval NIM_SWITCHES += --mm:$(NIM_MM))
endif
	$(NIM) $(NIM_COMPILES_TO) --out:$(ARCH_SO) --app:lib \
	  --nimcache:./.nimcache \
	  $(NIM_ARCH_FLAGS) $(NIM_DEFINES) \
	  $(NIM_SWITCHES) \
	  --hint[Processing]:off \
	  $(LIB_BASENAME).nim

nimc:
	$(MAKE) nim NIM_COMPILES_TO=c

nimcpp:
	$(MAKE) nim NIM_COMPILES_TO=cpp

nc:
	ln -sf $(ARCH_SO) $(DEFAULT_SO)
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
	  -vpicompat 1800v2009 \
	  -pliverbose \
	  +define+SHM_DUMP -debug \
	  +define+$(DEFINES) \
	  $(SV_FILES) \
	  +incdir+./ \
	  $(NOWARNS) \
	  $(NC_SWITCHES)

# $(C_FILES) -> $(DEFAULT_SO)
# -I$(XCELIUM_ROOT)/../include for "vpi_user.h"
clib:
	@find . \( -name *.o -o -name $(ARCH_SO) \) -delete
	gcc \
	  -c \
	  -fPIC \
	  -I$(XCELIUM_ROOT)/../include \
      -DVPI_COMPATIBILITY_VERSION_1800v2009 \
	  $(C_FILES) \
	  $(GCC_ARCH_FLAG)
	gcc -shared -Wl,-soname,$(DEFAULT_SO) $(GCC_ARCH_FLAG) *.o -o $(ARCH_SO)
	@rm -f *.o

$(SUBDIRS):
	$(MAKE) -C $@

all: $(SUBDIRS)

# Run "make ARCH=32" to build 32-bit libvpi_32.so and run 32-bit xrun.
# Run "make" to build 64-bit libvpi_64.so and run 64-bit xrun.
