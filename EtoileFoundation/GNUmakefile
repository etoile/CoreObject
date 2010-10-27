PACKAGE_NAME = EtoileFoundation

include $(GNUSTEP_MAKEFILES)/common.make

ifneq ($(test), yes)
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
LIBRARIES_DEPEND_UPON += -lm -lEtoileThread -lEtoileXML $(SSL_LIBS) \
	$(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

ifeq ($(test), yes)
EtoileFoundation_LDFLAGS += -lUnitKit $(SSL_LIBS)
endif

EtoileFoundation_SUBPROJECTS += Source

EtoileFoundation_HEADER_FILES_DIR = ./EtoileFoundation

EtoileFoundation_HEADER_FILES = \
	EtoileFoundation.h \
	ETGetOptionsDictionary.h \
	EtoileCompatibility.h \
	ETCArray.h \
	Macros.h \
	NSObject+Mixins.h \
	NSFileManager+TempFile.h \
	NSFileHandle+Socket.h\
	UKPluginsRegistry.h \
	ETByteSizeFormatter.h \
	ETClassMirror.h \
	ETCollection.h \
	ETCollection+HOM.h \
	ETFilter.h \
	ETHistory.h \
	ETInstanceVariableMirror.h \
	ETMethodMirror.h \
	ETObjectChain.h \
	ETObjectMirror.h \
	UKPluginsRegistry.h \
	ETPropertyValueCoding.h \
	ETPropertyViewpoint.h \
	ETProtocolMirror.h \
	ETRendering.h \
	ETSocket.h \
	ETStackTraceRecorder.h \
	ETTranscript.h \
	ETTransform.h \
	ETUUID.h \
	NSData+Hash.h\
	NSIndexPath+Etoile.h \
	NSIndexSet+Etoile.h \
	NSInvocation+Etoile.h \
	NSObject+Etoile.h \
	NSObject+HOM.h \
	NSObject+Model.h \
	NSObject+Prototypes.h \
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

ifeq ($(GNUSTEP_TARGET_CPU), ix86)
 ADDITIONAL_OBJCFLAGS += -march=i586
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
-include ../../etoile.make
-include etoile.make
-include ../../documentation.make
ifeq ($(test), yes)
include $(GNUSTEP_MAKEFILES)/bundle.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
