include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = LuceneKit_Source

LuceneKit_Source_SUBPROJECTS = \
	Importer \
	QueryParser \
	Search \
	Index \
	Document \
	Analysis \
	Util \
	Store \
	Java

LuceneKit_Source_OBJC_FILES = \
	LCIndexManager.m \
	LCMetadataAttribute.m

LuceneKit_Source_INCLUDE_DIRS += -I..

include $(GNUSTEP_MAKEFILES)/subproject.make

-include ../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
#-include ../GNUmakefile.postamble
