include $(GNUSTEP_MAKEFILES)/common.make

#test=yes

ifeq ($(test), yes)
BUNDLE_NAME = CoreObject
else
FRAMEWORK_NAME = CoreObject
endif

CoreObject_OBJCFLAGS += -std=c99 
CoreObject_LDFLAGS += -lEtoileFoundation -lEtoileSerialize
CoreObject_LIBRARIES_DEPEND_UPON += -lEtoileFoundation -lEtoileSerialize

CoreObject_SUBPROJECTS = Blocks

CoreObject_OBJC_FILES = \
	COCollection.m \
	COSmartGroup.m \
	COGroup.m \
	COFileObject.m \
	COObject.m \
	COObjectContext.m \
	COMultiValue.m \
	NSObject+CoreObject.m \
	CODirectory.m \
	COFile.m \
	COSerializer.m \
	CODeserializer.m \
	COMetadataServer.m

ifeq ($(test), yes)
CoreObject_OBJC_FILES += \
	TestCollection.m \
	TestSmartGroup.m \
	TestGroup.m \
	TestObject.m \
	TestMultiValue.m \
	TestSerializer.m \
	TestMetadataServer.m \
	TestFile.m \
	TestDirectory.m
endif

CoreObject_HEADER_FILES_DIR += Headers
CoreObject_HEADER_FILES = \
	CoreObject.h \
	COCollection.h \
	COSmartGroup.h \
	COGroup.h \
	COFileObject.h \
	COObject.h \
	COObjectContext.h \
	COMultiValue.h \
	COPropertyType.h \
	COUtility.h \
	NSObject+CoreObject.h \
	GNUstep.h \
	CODirectory.h \
	COFile.h \
	COSerializer.h \
	CODeserializer.h \
	COMetadataServer.h

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
	# TODO: Apple target broken currently, we may support compiling CoreObject 
	# without EtoileSerialize later to restore Cocoa compatibility
	CoreObject_OBJC_LIBS += -framework UnitKit -framework EtoileFoundation
endif
else
ifeq ($(test), yes)
	CoreObject_LDFLAGS += -lUnitKit -lEtoileFoundation -lEtoileSerialize
endif
endif

ADDITIONAL_OBJCFLAGS += -IHeaders/

ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make
-include GNUmakefile.postamble
endif
