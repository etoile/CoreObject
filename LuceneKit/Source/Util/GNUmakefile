include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = LuceneKit_Util

LuceneKit_Util_OBJC_FILES = \
	LCSmallFloat.m \
	NSString+Additions.m \
	NSData+Additions.m \
	LCBitVector.m \
	LCPriorityQueue.m 

ifeq ($(test), yes)
LuceneKit_Util_OBJC_FILES += \
	TestSmallFloat.m \
	TestString+Additions.m \
	TestData+Additions.m \
	TestPriorityQueue.m \
	TestBitVector.m 
endif


LuceneKit_Util_INCLUDE_DIRS += -I../..

-include ../../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
