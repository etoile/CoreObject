include $(GNUSTEP_MAKEFILES)/common.make

DOCUMENT_NAME = CoreObject

$(DOCUMENT_NAME)_AGSDOC_FILES += \
	COCoreObjectProtocol.h \
	COObject.h \
	COGroup.h \
	COSmartGroup.h \
	COFileObject.h \
	COObjectContext.h \
	COMultiValue.h \
	COPropertyType.h \
	CODirectory.h \
	COFile.h \
	COSerializer.h \
	CODeserializer.h \
	COMetadataServer.h \
	COObjectServer.h \
	COProxy.h

# FIXME: CoreObject.html generation fails with the following header...
#	NSObject+CoreObject.h \

$(DOCUMENT_NAME)_AGSDOC_FLAGS = \
	-MakeFrames YES \
	-HeaderDirectory ../Headers \
	-DocumentationDirectory . \
	-Warn YES \
	-ShowDependencies NO \
	-Declared CoreObject

#	-Clean YES
#	-IgnoreDependencies YES

# A small extension to let us specify a directory where the .m files can be 
# found. For now, trailing slash and multiple source directories in 
# input aren't supported
$(DOCUMENT_NAME)_SOURCE_DIRECTORY = ..

include $(GNUSTEP_MAKEFILES)/documentation.make

# We cannot give a Source directory to autogsdoc through gnustep-make, and 
# placing an explicit declaration such as 
# $(DOCUMENT_NAME)_AGSDOC_FILES += ../COObject.m
# doesn't help. It fails in two different ways if we put itbefore or after the 
# headers declared at the beginning. The result is the same at the end the doc 
# of the methods in .m files isn't ignored. Let's do an ugly hack with ln...
before-all::
	$(LN_S) -f $($(DOCUMENT_NAME)_SOURCE_DIRECTORY)/*.m .;

after-all::
	for mfile in *.m; do \
		if [ -L $$mfile ]; then \
			rm -f $$mfile; \
		fi; \
	done \

# clean is only for binary files, but there aren't any binary files in a doc 
# folder such as this one. So instead of letting people wondering why clean 
# doesn't clean, we call disclean. This may be changed later though...
after-clean:: distclean

# autogsdoc -Clean YES doesn't work well, it removes the html files if I pass *
# but that's it, so let's do it with rm...
after-distclean::
	rm -f *.igsdoc
	rm -f *.gsdoc
	rm -f *.html
