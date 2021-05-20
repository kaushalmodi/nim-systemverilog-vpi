# Time-stamp: <2021-05-20 02:34:24 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)

LIB_BASENAME ?= libdpi

# NIM_GC ?= arc     # FIXME: The arc GC is crashing -- Thu May 20 02:34:21 EDT 2021 - kmodi
NIM_GC ?= regions
NIM_SWITCHES ?= --expandMacro:vpiDefine
SV_FILES ?= vlab_probes_pkg.sv tb.sv

include $(GIT_ROOT)/makefile

default: nimcpp nc
