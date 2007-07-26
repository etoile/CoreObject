include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = UUID

#UUID_OBJC_FILES = 

UUID_OBJ_FILES = $(wildcard *.o)

include $(GNUSTEP_MAKEFILES)/subproject.make

before-all::
	if [ -f config.h ]; then \
		echo "Configured"; \
	else \
		echo "Configuring ..."; \
		./configure; \
	fi; \
	\
	if [ ! -f config.h ]; then \
		echo "Configuration failed"; \
		exit 0; \
	fi; \
	\
	echo "Building"; \
	make -f Makefile;

after-clean::
	if [ -f Makefile ]; then \
		make -f Makefile clean; \
	fi

after-distclean::
	if [ -f Makefile ]; then \
		make -f Makefile distclean; \
	fi

