# Time-stamp: <2021-05-13 20:36:48 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)
NIM_GC ?= arc
NIM_SWITCHES ?= --expandMacro:vpiDefine

include $(GIT_ROOT)/makefile

default: nimcpp nc
