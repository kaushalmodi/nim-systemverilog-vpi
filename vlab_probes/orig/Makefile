.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)

FILES   ?= vlab_probes_pkg.sv tb.sv

include $(GIT_ROOT)/makefile

create_symlink:
	ln -fs libvpi.so libdpi.so

default: clean clibvpi create_symlink nc
