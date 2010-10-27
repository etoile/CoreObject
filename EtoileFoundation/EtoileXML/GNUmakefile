include $(GNUSTEP_MAKEFILES)/common.make

# We reset PROJECT_DIR provided by etoile.make to match the subproject since 
# etoile.make doesn't detect and handle such embedded project
PROJECT_DIR = $(CURDIR)

FRAMEWORK_NAME = EtoileXML
$(FRAMEWORK_NAME)_VERSION = 0.1


# -lm for FreeBSD at least
LIBRARIES_DEPEND_UPON += -lm $(FND_LIBS) $(OBJC_LIBS) $(SYSTEM_LIBS)

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

-include ../../../etoile.make
-include ../../../documentation.make
include $(GNUSTEP_MAKEFILES)/framework.make
