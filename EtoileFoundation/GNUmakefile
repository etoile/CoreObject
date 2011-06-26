PACKAGE_NAME = EtoileFoundation

include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(test), yes)
SUBPROJECTS = Tests/PlugInExample
else
SUBPROJECTS = EtoileThread EtoileXML
endif

ifneq ($(findstring freebsd, $(GNUSTEP_HOST_OS)),)
  USE_SSL_PKG ?= no
endif

ifneq ($(findstring darwin, $(GNUSTEP_HOST_OS)),)
  USE_SSL_PKG ?= no
endif

ifneq ($(findstring linux, $(GNUSTEP_HOST_OS)),)
  USE_SSL_PKG ?= yes
endif

ifneq ($(findstring netbsd, $(GNUSTEP_HOST_OS)),)
  USE_SSL_PKG ?= no
endif

# pkg-config --libs openssl returns no result on Solaris
ifneq ($(findstring solaris, $(GNUSTEP_HOST_OS)),)
  USE_SSL_PKG ?= no
  ADDITIONAL_INCLUDE_DIRS += -I/usr/local/ssl/include
  ADDITIONAL_LIB_DIRS += -L/usr/local/ssl/lib
endif

export USE_SSL_PKG

ifeq ($(test), yes)
BUNDLE_NAME = EtoileFoundation
else
FRAMEWORK_NAME = EtoileFoundation
endif

VERSION = 0.4.1

# libssl and libcrypto are packaged together
ifeq ($(USE_SSL_PKG), yes)
SSL_LIBS = $(shell pkg-config --libs openssl)
else
SSL_LIBS = -lssl -lcrypto 
endif

# -lm for FreeBSD at least
LIBRARIES_DEPEND_UPON += -lm $(SSL_LIBS) \
	$(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

ifeq ($(test), yes)
EtoileFoundation_LDFLAGS += -lUnitKit $(SSL_LIBS)
endif

ifeq ($(USE_SSL_PKG), yes)
SSL_CFLAGS = $(shell pkg-config --cflags openssl)
endif

EtoileFoundation_CPPFLAGS += $(SSL_CFLAGS)
EtoileFoundation_CPPFLAGS += -D_GNU_SOURCE # For Linux
#EtoileFoundation_CPPFLAGS += -D_XOPEN_SOURCE=600 # For Solaris
EtoileFoundation_OBJCFLAGS += -std=c99 
EtoileFoundation_CFLAGS += -std=c99 $(SSL_CFLAGS)

ifeq ($(CC), clang)
ADDITIONAL_OBJCFLAGS += -fobjc-nonfragile-abi -fblocks
endif

EtoileFoundation_HEADER_FILES_DIR = Headers

EtoileFoundation_HEADER_FILES = \
	EtoileFoundation.h \
	ETGetOptionsDictionary.h \
	EtoileCompatibility.h \
	ETCArray.h \
	Macros.h \
	NSFileManager+TempFile.h \
	NSFileHandle+Socket.h\
	ETPlugInRegistry.h \
	ETByteSizeFormatter.h \
	ETClassMirror.h \
	ETCollection.h \
	ETCollection+HOM.h \
	ETHistory.h \
	ETInstanceVariableMirror.h \
	ETKeyValuePair.h \
	ETMethodMirror.h \
	ETObjectMirror.h \
	ETPlugInRegistry.h \
	ETPropertyValueCoding.h \
	ETPropertyViewpoint.h \
	ETProtocolMirror.h \
	ETSocket.h \
	ETStackTraceRecorder.h \
	ETTranscript.h \
	ETUUID.h \
	NSData+Hash.h\
	NSIndexPath+Etoile.h \
	NSIndexSet+Etoile.h \
	NSInvocation+Etoile.h \
	NSObject+DoubleDispatch.h \
	NSObject+Etoile.h \
	NSObject+HOM.h \
	NSObject+Model.h \
	NSObject+Prototypes.h \
	NSObject+Trait.h \
	NSString+Etoile.h \
	NSURL+Etoile.h \
	ETUTI.h \
	ETReflection.h \
	ETEntityDescription.h \
	ETModelDescriptionRepository.h \
	ETModelElementDescription.h \
	ETPackageDescription.h \
	ETPropertyDescription.h \
	ETValidationResult.h \
	runtime.h \
	glibc_hack_unistd.h

EtoileFoundation_RESOURCE_FILES = \
	UTIDefinitions.plist \
	UTIClassBindings.plist

# Deprecated
EtoileFoundation_HEADER_FILES += NSFileManager+NameForTempFile.h

EtoileFoundation_OBJC_FILES = \
	Source/NSFileManager+TempFile.m\
	Source/NSFileHandle+Socket.m\
	Source/ETByteSizeFormatter.m \
	Source/ETClassMirror.m \
	Source/ETCollection.m \
	Source/ETCollection+HOM.m \
	Source/ETGetOptionsDictionary.m \
	Source/ETHistory.m \
	Source/ETInstanceVariableMirror.m \
	Source/ETKeyValuePair.m \
	Source/ETMethodMirror.m \
	Source/ETObjectMirror.m \
	Source/ETPlugInRegistry.m \
	Source/ETPropertyViewpoint.m \
	Source/ETPropertyValueCoding.m \
	Source/ETProtocolMirror.m \
	Source/ETSocket.m \
	Source/ETStackTraceRecorder.m \
	Source/ETTranscript.m \
	Source/ETUUID.m \
	Source/ETUTI.m \
	Source/NSBlocks.m\
	Source/NSData+Hash.m\
	Source/NSIndexPath+Etoile.m \
	Source/NSIndexSet+Etoile.m \
	Source/NSInvocation+Etoile.m \
	Source/NSObject+DoubleDispatch.m \
	Source/NSObject+Etoile.m \
	Source/NSObject+HOM.m \
	Source/NSObject+Model.m \
	Source/NSObject+Prototypes.m \
	Source/NSObject+Trait.m \
	Source/NSString+Etoile.m \
	Source/NSURL+Etoile.m \
	Source/ETReflection.m \
	Source/ETEntityDescription.m \
	Source/ETModelDescriptionRepository.m \
	Source/ETModelElementDescription.m \
	Source/ETPackageDescription.m \
	Source/ETPropertyDescription.m \
	Source/ETValidationResult.m

EtoileFoundation_C_FILES = Source/ETCArray.c

# Deprecated
EtoileFoundation_OBJC_FILES += Source/NSFileManager+NameForTempFile.m

ifeq ($(test), yes)
EtoileFoundation_OBJC_FILES += \
	Tests/TestBasicHOM.m \
	Tests/TestCollectionTrait.m \
	Tests/TestETCollectionHOM.m \
	Tests/TestEntityDescription.m \
	Tests/TestIndexPath.m \
	Tests/TestModelDescriptionRepository.m \
	Tests/TestTrait.m \
	Tests/TestPlugInRegistry.m \
	Tests/TestReflection.m \
	Tests/TestStackTraceRecorder.m \
	Tests/TestString.m \
	Tests/TestUTI.m \
	Tests/TestUUID.m
endif

ifeq ($(GNUSTEP_TARGET_CPU), ix86)
 ADDITIONAL_OBJCFLAGS += -march=i586
endif

ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
-include ../../etoile.make
-include etoile.make
-include ../../documentation.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
