include $(GNUSTEP_MAKEFILES)/common.make
clean : test=yes
ifeq ($(test), yes)
BUNDLE_NAME=CoreObject
else
FRAMEWORK_NAME=CoreObject
endif

CC=clang
CXX=clang

CoreObject_OBJC_FILES = $(wildcard CO*.m) $(wildcard NS*.m)
ifeq ($(test), yes)
CoreObject_OBJC_FILES += $(wildcard Test*.m)
endif
CoreObject_OBJCC_FILES = $(wildcard *.mm)
CoreObject_HEADER_FILES = $(wildcard *.h)
CoreObject_C_FILES= $(wildcard *.c)
CoreObject_OBJC_LIBS = -lEtoileFoundation 
CoreObject_CPPFLAGS=-Ifmdb/src -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS
CoreObject_SUBPROJECTS = fmdb
CoreObject_NEEDS_GUI = no
ADDITIONAL_OBJCFLAGS = -Werror
ADDITIONAL_OBJCCFLAGS = -Werror

SUBPROJECTS=fmdb

LIBRARIES_DEPEND_UPON = -lEtoileFoundation $(FND_LIBS)

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/bundle.make	
include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make

