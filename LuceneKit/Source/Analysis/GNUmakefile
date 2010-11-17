include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = LuceneKit_Analysis

LuceneKit_Analysis_OBJC_FILES = \
	LCToken.m \
	LCTokenStream.m \
	LCTokenFilter.m \
	LCTokenizer.m \
	LCAnalyzer.m \
	LCCharTokenizer.m \
	LCWhitespaceTokenizer.m \
	LCWhitespaceAnalyzer.m \
	LCLetterTokenizer.m \
	LCLowerCaseTokenizer.m \
	LCLowerCaseFilter.m \
	LCStopFilter.m \
	LCStopAnalyzer.m \
	LCSimpleAnalyzer.m \
	LCPerFieldAnalyzerWrapper.m \
	LCPorterStemFilter.m \
	LCWordlistLoader.m

LuceneKit_Analysis_C_FILES = \
	PorterStemmer.c

ifeq ($(test), yes)
LuceneKit_Analysis_OBJC_FILES += \
	TestWhitespaceAnalyzer.m \
	TestStopAnalyzer.m \
	TestSimpleAnalyzer.m \
	TestAnalyzer.m 
endif

LuceneKit_Analysis_INCLUDE_DIRS += -I../..

-include ../../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
