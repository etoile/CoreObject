#ifndef __LUCENE_SEARCH_FILTERED_QUERY__
#define __LUCENE_SEARCH_FILTERED_QUERY__

#include "LCQuery.h"
#include "LCWeight.h"

@class LCFilter;

@interface LCFilteredQuery: LCQuery
{
	LCQuery *query;
	LCFilter *filter;
}

- (id) initWithQuery: (LCQuery *) query filter: (LCFilter *) filter;
- (id <LCWeight>) createWeight: (LCSearcher *) searcher;
- (float) value;
- (float) sumOfSquaredWeights;
- (void) normalize: (float) v;
- (LCExplanation *) explain: (LCIndexReader *) ir doc: (int) i;
- (LCQuery *) query;
- (LCScorer *) scorer: (LCIndexReader *) indexReader;
- (BOOL) next;
- (int) doc;
- (BOOL) skipTo: (int) target;
- (float) score;
- (LCExplanation *) explain: (int) i;
- (LCQuery *) rewrite: (LCIndexReader *) reader;
- (LCQuery *) query;

@end

#endif /* __LUCENE_SEARCH_FILTERED_QUERY__ */
