include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = LuceneKit_Search

LuceneKit_Search_OBJC_FILES = \
	LCBooleanClause.m \
	LCBooleanQuery.m \
	LCBooleanScorer.m \
	LCTopDocs.m \
	LCTopFieldDocs.m \
	LCScoreDoc.m \
	LCFieldDoc.m \
	LCFilter.m \
	LCFieldCache.m \
	LCFieldCacheImpl.m \
	LCFieldSortedHitQueue.m \
	LCHit.m \
	LCHits.m \
	LCHitCollector.m \
	LCHitQueue.m \
	LCHitIterator.m \
	LCTopDocCollector.m \
	LCTopFieldDocCollector.m \
	LCExplanation.m \
	LCReqExclScorer.m \
	LCReqOptSumScorer.m \
	LCConjunctionScorer.m \
	LCDisjunctionSumScorer.m \
	LCNonMatchingScorer.m \
	LCQuery.m \
	LCQueryFilter.m \
	LCQueryTermVector.m \
	LCIndexSearcher.m \
	LCSearcher.m \
	LCScorer.m \
	LCSortField.m \
	LCScoreDocComparator.m \
	LCSort.m \
	LCSortComparator.m \
	LCSimilarity.m  \
	LCDefaultSimilarity.m \
	LCSimilarityDelegator.m \
	LCTermQuery.m \
	LCTermScorer.m \
	LCPrefixQuery.m \
	LCFilteredTermEnum.m \
	LCMultiTermQuery.m \
	LCFuzzyQuery.m \
	LCFuzzyTermEnum.m \
	LCWildcardQuery.m \
	LCWildcardTermEnum.m \
	LCRangeQuery.m 

ifeq ($(test), yes)
LuceneKit_Search_OBJC_FILES += \
	TestRangeQuery.m \
	TestBooleanMinShouldMatch.m \
	TestWildcard.m \
	TestFuzzyQuery.m \
	TestPrefixQuery.m \
	TestSort.m \
	TestBoolean2.m \
	TestQueryTermVector.m \
	TestTermVectors.m \
	TestBooleanQuery.m \
	TestBooleanScorer.m \
	TestBooleanOr.m \
	TestNot.m \
	TestDocBoost.m \
	TestSetNorm.m \
	TestSimilarity.m \
	TestEnglish.m \
	TestCheckHits.m 
endif

LuceneKit_Search_INCLUDE_DIRS += -I../.. `onig-config --cflags`

-include ../../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
