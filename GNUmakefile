include $(GNUSTEP_MAKEFILES)/common.make

#test=yes

ifeq ($(test), yes)
BUNDLE_NAME = CoreObject
else
FRAMEWORK_NAME = CoreObject
endif

CoreObject_SUBPROJECTS = \
	UUID \
	Blocks

CoreObject_OBJC_FILES = \
	COCollection.m \
	COSmartGroup.m \
	COGroup.m \
	COFileObject.m \
	COObject.m \
	COMultiValue.m \
	COUUID.m

ifeq ($(test), yes)
CoreObject_OBJC_FILES += \
	TestCollection.m \
	TestSmartGroup.m \
	TestGroup.m \
	TestObject.m \
	TestMultiValue.m \
	TestUUID.m 
endif

CoreObject_HEADER_FILES_DIR += Headers
CoreObject_HEADER_FILES = \
	CoreObject.h \
	COCollection.h \
	COSmartGroup.h \
	COGroup.h \
	COFileObject.h \
	COObject.h \
	COMultiValue.h \
	COPropertyType.h \
	COUUID.h \
	GNUstep.h

# Blocks
CoreObject_HEADER_FILES += \
	Blocks.h \
	BKExtension.h \
	BKExtensionPoint.h \
	BKLog.h \
	BKPlugin.h \
	BKPluginRegistry.h \
	BKRequirement.h \

CoreObject_RESOURCE_FILES += \
	Blocks/plugin.xml \
	Blocks/Info.plist

ifeq ($(FOUNDATION_LIB), apple)
ifeq ($(test), yes)
	CoreObject_OBJC_LIBS += -framework UnitKit
endif
else
ifeq ($(test), yes)
	CoreObject_LDFLAGS += -lUnitKit
endif
endif

ADDITIONAL_OBJCFLAGS += -IHeaders/

ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
endif
