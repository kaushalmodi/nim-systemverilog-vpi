# Time-stamp: <2021-05-24 00:32:01 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)

LIB_BASENAME ?= libdpi

SV_FILES ?= vpi_pkg.sv tb.sv
NC_SWITCHES ?= -xmerror ENUMERR

include $(GIT_ROOT)/makefile

default: nimcpp nc
