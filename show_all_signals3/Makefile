# Time-stamp: <2021-05-19 20:40:04 kmodi>

.DEFAULT_GOAL := default

GIT_ROOT = $(shell git rev-parse --show-toplevel)
NIM_SWITCHES ?= --expandMacro:vpiDefine

include $(GIT_ROOT)/makefile

default: nimcpp nc
