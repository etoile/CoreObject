include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = LuceneKit_Document

LuceneKit_Document_OBJC_FILES = \
	LCNumberTools.m \
	LCDateTools.m \
	LCField.m \
	LCDocument.m

ifeq ($(test), yes)
LuceneKit_Document_OBJC_FILES += \
	TestDocument.m \
	TestDateTools.m \
        TestNumberTools.m \
	TestBinaryDocument.m
endif


LuceneKit_Document_INCLUDE_DIRS += -I../..

-include ../../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
