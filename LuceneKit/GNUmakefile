include $(GNUSTEP_MAKEFILES)/common.make
-include GNUmakefile.options

ifeq ($(test), yes)
BUNDLE_NAME = LuceneKit
else
LIBRARY_NAME = LuceneKit
endif

LuceneKit_VERSION = 0.1.1

-include GNUmakefile.headers

LuceneKit_SUBPROJECTS = Source

ifeq ($(FOUNDATION_LIB), apple)
	LuceneKit_LIBRARIES_DEPEND_UPON = -lz $(REGEXP_ADDITIONAL_LIBRARIES)
	LuceneKit_OBJC_LIBS = -lz $(REGEXP_ADDITIONAL_LIBRARIES)
	ifeq ($(test), yes)
		LuceneKit_OBJC_LIBS += -framework UnitKit
	endif
else
	#LuceneKit_OBJC_LIBS = -lgnustep-base
	LuceneKit_LIBRARIES_DEPEND_UPON = -lz $(REGEXP_ADDITIONAL_LIBRARIES)
	LuceneKit_LDFLAGS = -lgnustep-base -lz $(REGEXP_ADDITIONAL_LIBRARIES)
	ifeq ($(test), yes)
		LuceneKit_LDFLAGS += -lUnitKit
	endif
endif

ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/library.make
endif

-include GNUmakefile.headers_build

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include ../../etoile.make
-include GNUmakefile.postamble
