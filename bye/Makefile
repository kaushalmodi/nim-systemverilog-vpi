# Time-stamp: <2021-05-19 09:59:21 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)
NIM_GC ?= arc
NIM_SWITCHES ?= --expandMacro:vpiDefine
NIM_SWITCHES += --define:dontSetStartupRoutinesInLibs

include $(GIT_ROOT)/makefile

default: nimcpp nc
