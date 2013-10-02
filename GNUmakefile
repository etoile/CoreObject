PACKAGE_NAME = CoreObject

include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = CoreObject
VERSION = 0.5

LIBRARIES_DEPEND_UPON = $(shell pkg-config --libs sqlite3) -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

CoreObject_INCLUDE_DIRS = -IStore/fmdb/src
CoreObject_LDFLAGS += -lstdc++ -lobjcxx -lsqlite3 -ldispatch
CoreObject_OBJCFLAGS += -fobjc-arc

ifeq ($(test), yes)
  BUNDLE_NAME = $(FRAMEWORK_NAME)
  CoreObject_LDFLAGS += -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)
  CoreObject_PRINCIPAL_CLASS = TestCommon
endif

OTHER_HEADER_DIRS = . Core Diff Model Store Undo Tracks Synchronization Utilities StorageDataModel

CoreObject_HEADER_FILES_DIR = Headers
CoreObject_HEADER_FILES = $(notdir $(wildcard Headers/*.h))

CoreObject_OBJC_FILES += $(wildcard Core/*.m)
CoreObject_OBJC_FILES += $(wildcard Diff/*.m)
CoreObject_OBJCC_FILES = $(wildcard Diff/*.mm)
CoreObject_CC_FILES = $(wildcard Diff/*.cc)
CoreObject_OBJC_FILES += $(wildcard Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Store/*.m)
CoreObject_C_FILES = $(wildcard Store/*.c)
CoreObject_OBJC_FILES += $(wildcard Undo/*.m)
CoreObject_OBJC_FILES += $(wildcard Tracks/*.m)
CoreObject_OBJC_FILES += $(wildcard Utilities/*.m)
CoreObject_OBJC_FILES += $(wildcard StorageDataModel/*.m)
CoreObject_OBJC_FILES += $(wildcard Synchronization/*.m)
# Don't compile fmdb/src/fmdb.m
CoreObject_OBJC_FILES += $(wildcard Store/fmdb/src/FM*.m)

ifeq ($(test), yes)
CoreObject_OBJC_FILES += $(wildcard Tests/*.m)
endif

clean : test=yes

include $(GNUSTEP_MAKEFILES)/aggregate.make
-include ../../etoile.make
-include etoile.make
ifeq ($(test), yes)
  include $(GNUSTEP_MAKEFILES)/bundle.make
else	
  include $(GNUSTEP_MAKEFILES)/framework.make
endif
