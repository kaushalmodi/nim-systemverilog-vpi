.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)

LIB_BASENAME ?= libdpi
SV_FILES ?= vlab_probes_pkg.sv tb.sv

include $(GIT_ROOT)/makefile

default: clean clib nc
