PACKAGE_NAME = CoreObject

include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = CoreObject

# ABI version (the API version is in CFBundleShortVersionString of FrameworkSource/Info.plist)
VERSION = 0.5

LIBRARIES_DEPEND_UPON = $(shell pkg-config --libs sqlite3) -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

# For test builds, pass one more libdispatch include directory located in GNUstep Local domain
CoreObject_INCLUDE_DIRS = -IStore/fmdb/src -I$(GNUSTEP_LOCAL_LIBRARIES)/Headers/dispatch
CoreObject_CPPFLAGS += -DGNUSTEP_MISSING_API_COMPATIBILITY -DOS_OBJECT_USE_OBJC=0
CoreObject_LDFLAGS += -lsqlite3 -ldispatch
# TODO: Check that -fobjc-arc is all we need to pass, then remove -fobjc-nonfragile-abi -fblocks
CoreObject_OBJCFLAGS += -fblocks -fobjc-arc -Wall -Wno-arc-performSelector-leaks
LD=${CXX}

ifeq ($(test), yes)
  BUNDLE_NAME = $(FRAMEWORK_NAME)
  CoreObject_INCLUDE_DIRS += -I$(PROJECT_DIR)/Tests -I$(PROJECT_DIR)/Tests/TestModelObjects -I$(PROJECT_DIR)/Tests/Extras/Model 
  CoreObject_OBJCFLAGS += -Wno-unused-variable -Wno-unused-value
  CoreObject_LDFLAGS += -lEtoileFoundation $(GUI_LIBS) $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)
  CoreObject_PRINCIPAL_CLASS = EditingContextTestCase
else
  CoreObject_OBJCFLAGS += -Wextra -Wno-sign-compare -Wno-unused-parameter
endif

# For running the test suite without a SSD (see also prepare-coreobject-ramdisk.sh that must be run before)
ifeq ($(ramdisk), yes)
  CoreObject_CPPFLAGS += -DIN_MEMORY_STORE
endif

OTHER_HEADER_DIRS = . Core Debugging Diff Extras/Diff Extras/Model Extras/ValueTransformers Model Store Undo Synchronization Synchronization/Messages Utilities StorageDataModel SchemaMigration

CoreObject_HEADER_FILES_DIR = $(COLLECTED_HEADER_DIR)
CoreObject_HEADER_FILES = $(foreach dir, ${OTHER_HEADER_DIRS}, $(notdir $(wildcard ${dir}/*.h)))

CoreObject_OBJC_FILES += $(wildcard Core/*.m)
CoreObject_OBJC_FILES += $(wildcard Diff/*.m)
CoreObject_OBJCC_FILES += $(wildcard Diff/*.mm)
CoreObject_CC_FILES += $(wildcard Diff/*.cc)
CoreObject_OBJC_FILES += $(wildcard Debugging/*.m)
CoreObject_OBJC_FILES += $(wildcard Extras/Diff/*.m)
CoreObject_OBJC_FILES += $(wildcard Extras/Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Extras/ValueTransformers/*.m)
CoreObject_OBJC_FILES += $(wildcard Localization/*.m)
CoreObject_OBJC_FILES += $(wildcard Model/*.m)
CoreObject_OBJC_FILES += $(wildcard SchemaMigration/*.m)
CoreObject_OBJC_FILES += $(wildcard Store/*.m)
CoreObject_C_FILES += $(wildcard Store/*.c)
CoreObject_OBJC_FILES += $(wildcard Undo/*.m)
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
#CoreObject_OBJC_FILES += $(wildcard Tests/Extras/Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Model/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Relationship/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/SchemaMigration/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/StorageDataModel/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Store/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Undo/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Serialization/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/TestModelObjects/*.m)
CoreObject_OBJC_FILES += $(wildcard Tests/Utilities/*.m)
endif

CoreObject_LANGUAGES = English French
CoreObject_RESOURCE_FILES_DIR = Localization
CoreObject_LOCALIZED_RESOURCE_FILES = Commits

CoreObjectDoc_MENU_TEMPLATE_FILE = Documentation/Templates/menu.html

CoreObjectDoc_HEADER_DIRS =
CoreObjectDoc_SOURCE_DIRS =
CoreObjectDoc_DOC_FILES = \
	Core/COBranch.h \
	Core/COEditingContext.h \
	Core/COEditingContext+Debugging.h \
	Core/COObject.h \
	Core/COObjectGraphContext.h \
	Core/COObjectGraphContext+Debugging.h \
	Core/COPersistentRoot.h \
	Core/COQuery.h \
	Core/COSerialization.h \
	Core/CORevision.h \
	Model/COBookmark.h \
	Model/COContainer.h \
	Model/COCollection.h \
	Model/COGroup.h \
	Model/COLibrary.h \
	Model/COTag.h \
	SchemaMigration/COModelElementMove.h \
	SchemaMigration/COSchemaMigration.h \
	SchemaMigration/COSchemaMigrationDriver.h \
	StorageDataModel/COAttachmentID.h \
	StorageDataModel/COItemGraph.h \
	StorageDataModel/COItem.h \
	StorageDataModel/COItem+JSON.h \
	StorageDataModel/COPath.h \
	StorageDataModel/COType.h \
	Undo/COCommand.h \
	Undo/COCommandGroup.h \
	Undo/COTrack.h \
	Undo/COUndoTrack.h \
	Utilities/COCommitDescriptor.h \
	Utilities/CODateSerialization.h \
	Utilities/COError.h  

include $(GNUSTEP_MAKEFILES)/aggregate.make
-include ../../etoile.make
-include etoile.make
-include ../../documentation.make
ifeq ($(test), yes)
  include $(GNUSTEP_MAKEFILES)/bundle.make
else	
  include $(GNUSTEP_MAKEFILES)/framework.make
endif

after-clean::
	rm -rf CoreObject.bundle
