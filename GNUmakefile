PACKAGE_NAME = CoreObject

include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(test), yes)
BUNDLE_NAME = CoreObject
else
FRAMEWORK_NAME = CoreObject
endif

VERSION = 0.5

CC = clang
CXX = clang
LD = $(CXX)

CoreObject_SUBPROJECTS = fmdb

CoreObject_INCLUDE_DIRS = -Ifmdb/src 
CoreObject_CPPFLAGS = -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS
CoreObject_LDFLAGS += -lstdc++ -lobjcxx
ifeq ($(test), yes)
CoreObject_LDFLAGS += -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)
CoreObject_PRINCIPAL_CLASS = TestCommon
endif
LIBRARIES_DEPEND_UPON = -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

CoreObject_OBJC_FILES = $(wildcard CO*.m) $(wildcard NS*.m)
ifeq ($(test), yes)
CoreObject_OBJC_FILES += \
	TestArrayDiff.m \
	TestCommon.m \
	TestCopy.m \
	TestEditingContext.m \
	TestHistoryTrack.m \
	TestObjectGraphDiff.m \
	TestPerformance.m \
	TestRelationshipIntegrity.m \
	TestRevisionNumber.m \
	TestSynchronization.m \
	TestStore.m \
	TestUtilities.m
endif
CoreObject_OBJCC_FILES = $(wildcard *.mm)
CoreObject_C_FILES= $(wildcard *.c)
CoreObject_HEADER_FILES = $(wildcard *.h)

clean : test=yes

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/bundle.make	
include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make
-include etoile.make
