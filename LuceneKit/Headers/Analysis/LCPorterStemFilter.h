#ifndef __LUCENE_ANALYSIS_PORTERSTEM_FILTER__
#define __LUCENE_ANALYSIS_PORTERSTEM_FILTER__

#include "LCTokenFilter.h"
#include "PorterStemmer.h"

@interface LCPorterStemFilter: LCTokenFilter
{
	struct stemmer *st;
}

@end

#endif /* __LUCENE_ANALYSIS_PORTERSTEM_FILTER__ */
