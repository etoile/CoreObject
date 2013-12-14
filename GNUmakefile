PACKAGE_NAME = CoreObject

include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = CoreObject
VERSION = 0.5

LIBRARIES_DEPEND_UPON = $(shell pkg-config --libs sqlite3) -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

# For test builds, pass one more libdispatch include directory located in GNUstep Local domain
CoreObject_INCLUDE_DIRS = -IStore/fmdb/src -I$(GNUSTEP_LOCAL_ROOT)/Library/Headers/dispatch
CoreObject_LDFLAGS += -lstdc++ -lobjcxx -lsqlite3 -ldispatch
CoreObject_OBJCFLAGS += -fobjc-arc -Wno-arc-performSelector-leaks -Wall

ifeq ($(test), yes)
  BUNDLE_NAME = $(FRAMEWORK_NAME)
  CoreObject_INCLUDE_DIRS += -I$(PROJECT_DIR)/Tests -I$(PROJECT_DIR)/Tests/TestModelObjects
  CoreObject_LDFLAGS += -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)
  CoreObject_PRINCIPAL_CLASS = TestCommon
endif

OTHER_HEADER_DIRS = . Core Diff Extras/Model Extras/ValueTransformers Model Store Undo Tracks Synchronization Synchronization/Messages Utilities StorageDataModel

CoreObject_HEADER_FILES_DIR = Headers
CoreObject_HEADER_FILES = $(notdir $(wildcard Headers/*.h))

CoreObject_OBJC_FILES += $(wildcard Core/*.m)
CoreObject_OBJC_FILES += $(wildcard Diff/*.m)
CoreObject_OBJCC_FILES = $(wildcard Diff/*.mm)
CoreObject_CC_FILES = $(wildcard Diff/*.cc)
CoreObject_OBJC_FILES += $(wildcard Extras/Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Extras/ValueTransformers/*.m)
CoreObject_OBJC_FILES += $(wildcard Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Store/*.m)
CoreObject_C_FILES = $(wildcard Store/*.c)
CoreObject_OBJC_FILES += $(wildcard Debugging/*.m)
CoreObject_OBJC_FILES += $(wildcard Undo/*.m)
CoreObject_OBJC_FILES += $(wildcard Tracks/*.m)
CoreObject_OBJC_FILES += $(wildcard Utilities/*.m)
CoreObject_OBJC_FILES += $(wildcard StorageDataModel/*.m)
CoreObject_OBJC_FILES += $(wildcard Synchronization/*.m)
CoreObject_OBJC_FILES += $(wildcard Synchronization/Messages/*.m)
# Don't compile fmdb/src/fmdb.m
CoreObject_OBJC_FILES += $(wildcard Store/fmdb/src/FM*.m)

ifeq ($(test), yes)
CoreObject_OBJC_FILES += $(wildcard Tests/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Attribute/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Core/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Diff/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Relationship/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/StorageDataModel/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Store/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Undo/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/TestModelObjects/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Utilities/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Serialization/*.m)
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
