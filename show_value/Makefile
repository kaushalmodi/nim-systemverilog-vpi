# Time-stamp: <2021-05-07 16:00:34 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)
NIM_GC ?= arc
NIM_SWITCHES ?= --expandMacro:vpiRegisterTask

include $(GIT_ROOT)/makefile

default: nimcpp nc
