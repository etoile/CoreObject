include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME=CoreObject
CC=clang
CXX=clang

CoreObject_OBJC_FILES = $(wildcard CO*.m) $(wildcard NS*.m)
CoreObject_OBJCC_FILES = $(wildcard *.mm)
CoreObject_HEADER_FILES = $(wildcard *.h)
CoreObject_C_FILES= $(wildcard *.c)
CoreObject_CPPFLAGS=-Ifmdb/src -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS
CoreObject_SUBPROJECTS = fmdb
ADDITIONAL_OBJCFLAGS = -Werror
ADDITIONAL_OBJCCFLAGS = -Werror

SUBPROJECTS=fmdb

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/framework.make