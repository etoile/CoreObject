include $(GNUSTEP_MAKEFILES)/common.make
clean : test=yes
ifeq ($(test), yes)
BUNDLE_NAME=ObjectMerging
else
FRAMEWORK_NAME=ObjectMerging
endif

CC=clang
CXX=clang

ObjectMerging_OBJC_FILES = $(wildcard CO*.m) $(wildcard NS*.m)
ifeq ($(test), yes)
ObjectMerging_OBJC_FILES += $(wildcard Test*.m)
endif
ObjectMerging_OBJCC_FILES = $(wildcard *.mm)
ObjectMerging_HEADER_FILES = $(wildcard *.h)
ObjectMerging_C_FILES= $(wildcard *.c)
ObjectMerging_OBJC_LIBS = -lEtoileFoundation 
ObjectMerging_CPPFLAGS=-Ifmdb/src -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS
ObjectMerging_SUBPROJECTS = fmdb
ObjectMerging_NEEDS_GUI = no
ADDITIONAL_OBJCFLAGS = -Werror
ADDITIONAL_OBJCCFLAGS = -Werror

SUBPROJECTS=fmdb

LIBRARIES_DEPEND_UPON = -lEtoileFoundation $(FND_LIBS)

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/bundle.make	
include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make

