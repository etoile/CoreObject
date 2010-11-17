#ifndef __LUCENE_SEARCH_QUERY_TERM_VECTOR__
#define __LUCENE_SEARCH_QUERY_TERM_VECTOR__

#include "LCTermFreqVector.h"

@class LCAnalyzer;

@interface LCQueryTermVector: NSObject <LCTermFrequencyVector>
{
	NSMutableArray *terms;
	NSMutableArray *termFreqs;
}

- (id) initWithQueryTerms: (NSArray *) queryTerms;
- (id) initWithString: (NSString *) queryString
			 analyzer: (LCAnalyzer *) analyzer;
@end

#endif /* __LUCENE_SEARCH_QUERY_TERM_VECTOR__ */
