include $(GNUSTEP_MAKEFILES)/common.make

#test=yes

ifeq ($(test), yes)
BUNDLE_NAME = OrganizeKit
else
FRAMEWORK_NAME = OrganizeKit
endif

OrganizeKit_SUBPROJECTS = \
	UUID \
	Blocks

OrganizeKit_OBJC_FILES = \
	OKCollection.m \
	OKSmartGroup.m \
	OKGroup.m \
	OKFileObject.m \
	OKObject.m \
	OKMultiValue.m \
	OKUUID.m

ifeq ($(test), yes)
OrganizeKit_OBJC_FILES += \
	TestCollection.m \
	TestSmartGroup.m \
	TestGroup.m \
	TestObject.m \
	TestMultiValue.m \
	TestUUID.m 
endif

OrganizeKit_HEADER_FILES_DIR += Headers
OrganizeKit_HEADER_FILES = \
	OrganizeKit.h \
	OKCollection.h \
	OKSmartGroup.h \
	OKGroup.h \
	OKFileObject.h \
	OKObject.h \
	OKMultiValue.h \
	OKPropertyType.h \
	OKUUID.h \
	GNUstep.h

# Blocks
OrganizeKit_HEADER_FILES += \
	Blocks.h \
	BKExtension.h \
	BKExtensionPoint.h \
	BKLog.h \
	BKPlugin.h \
	BKPluginRegistry.h \
	BKRequirement.h \

OrganizeKit_RESOURCE_FILES += \
	Blocks/plugin.xml \
	Blocks/Info.plist

ifeq ($(FOUNDATION_LIB), apple)
ifeq ($(test), yes)
	OrganizeKit_OBJC_LIBS += -framework UnitKit
endif
else
ifeq ($(test), yes)
	OrganizeKit_LDFLAGS += -lUnitKit
endif
endif

ADDITIONAL_OBJCFLAGS += -IHeaders/

ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
-include GNUmakefile.postamble
endif
