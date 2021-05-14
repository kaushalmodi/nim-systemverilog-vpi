# Time-stamp: <2021-05-13 23:48:19 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)
NIM_GC ?= arc
NIM_SWITCHES ?= --expandMacro:vpiDefine

include $(GIT_ROOT)/makefile

default: nimcpp nc
