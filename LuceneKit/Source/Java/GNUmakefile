include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = LuceneKit_Java

LuceneKit_Java_OBJC_FILES = \
	LCStringReader.m

ifeq ($(test), yes)
LuceneKit_Java_OBJC_FILES += \
	TestStringReader.m
endif

LuceneKit_Java_INCLUDE_DIRS += -I../..

-include ../../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
