include $(GNUSTEP_MAKEFILES)/common.make

#test=yes

ifeq ($(test), yes)
BUNDLE_NAME = CoreObject
else
FRAMEWORK_NAME = CoreObject
CoreObject_VERSION = 0.4
endif

CoreObject_OBJCFLAGS += -std=c99 
CoreObject_INCLUDE_DIRS += -I`pg_config --includedir`
CoreObject_LIB_DIRS += -L`pg_config --libdir`
CoreObject_LIBRARIES_DEPEND_UPON += -lEtoileFoundation -lEtoileSerialize -lpq \
	$(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)


CoreObject_OBJC_FILES = \
	COCollection.m \
	COSmartGroup.m \
	COGroup.m \
	COFileObject.m \
	COObject.m \
	COPersistentPool.m \
	COObjectContext.m \
	COObjectContext+GraphRollback.m \
	COMultiValue.m \
	COPropertyListFormat.m \
	NSObject+CoreObject.m \
	CODirectory.m \
	COFile.m \
	COSerializer.m \
	CODeserializer.m \
	COMetadataServer.m \
	COObjectServer.m \
	COProxy.m

ifeq ($(test), yes)
CoreObject_CPPFLAGS += -DUKTEST=1
CoreObject_OBJC_FILES += \
	TestCollection.m \
	TestSmartGroup.m \
	TestGroup.m \
	TestObject.m \
	TestMultiValue.m \
	TestFile.m \
	TestDirectory.m \
	TestSerializer.m \
	TestObjectContext.m \
	TestMetadataServer.m \
	TestObjectServer.m \
	TestGraphRollback.m \
	TestProxy.m
endif

CoreObject_HEADER_FILES_DIR += Headers
CoreObject_HEADER_FILES = \
	CoreObject.h \
	COCoreObjectProtocol.h \
	COCollection.h \
	COSmartGroup.h \
	COGroup.h \
	COFileObject.h \
	COObject.h \
	COPersistentPool.h \
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
	COMetadataServer.h \
	COObjectServer.h \
	COProxy.h

ifeq ($(test), yes)
	CoreObject_LDFLAGS += -lUnitKit -lEtoileFoundation -lEtoileSerialize -lpq
endif

# TODO: Remove
ADDITIONAL_OBJCFLAGS += -IHeaders/

ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../etoile.make
-include GNUmakefile.postamble
endif
