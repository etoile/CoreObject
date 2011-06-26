include $(GNUSTEP_MAKEFILES)/common.make

# We reset PROJECT_DIR provided by etoile.make to match the subproject since 
# etoile.make doesn't detect and handle such embedded project
PROJECT_DIR = $(CURDIR)

FRAMEWORK_NAME = EtoileXML
$(FRAMEWORK_NAME)_VERSION = 0.1

# -lm for FreeBSD at least
LIBRARIES_DEPEND_UPON += -lm -lEtoileFoundation $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

# For EtoileFoundation, etoile.make after-all:: is not executed before all 
# subprojects are built. Hence libEtoileFoundation.so is not present in the  
# Build directory at EtoileXML build time.
$(FRAMEWORK_NAME)_LIB_DIRS += -L../EtoileFoundation.framework
$(FRAMEWORK_NAME)_OBJCFLAGS += -std=c99

$(FRAMEWORK_NAME)_OBJC_FILES = \
	ETXMLNode.m \
	ETXMLDeclaration.m \
	ETXMLNullHandler.m \
	ETXMLParser.m \
	ETXMLXHTML-IMParser.m \
	ETXMLString.m\
	ETXMLWriter.m

$(FRAMEWORK_NAME)_HEADER_FILES = \
	ETXMLNode.h \
	ETXMLDeclaration.h \
	ETXMLParser.h \
	ETXMLString.h \
	ETXMLNullHandler.h \
	ETXMLXHTML-IMParser.h \
	ETXMLParserDelegate.h \
	ETXMLWriter.h\
	NSAttributedString+HTML.h

include $(GNUSTEP_MAKEFILES)/framework.make
-include ../../../etoile.make
-include ../../../documentation.make
