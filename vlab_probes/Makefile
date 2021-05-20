# Time-stamp: <2021-05-20 09:11:34 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)

LIB_BASENAME ?= libdpi

NIM_SWITCHES ?= --expandMacro:vpiDefine
SV_FILES ?= vlab_probes_pkg.sv tb.sv

include $(GIT_ROOT)/makefile

default: nimcpp nc
