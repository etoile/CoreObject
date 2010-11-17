#ifndef __LUCENE_SEARCH_SEARCHER__
#define __LUCENE_SEARCH_SEARCHER__

#include "LCSearchable.h"

@class LCSimilarity;
@class LCHits;
@class LCQuery;
@class LCSort;
@class LCFilter;
@class LCHitCollector;

@interface LCSearcher: NSObject <LCSearchable>
{
	LCSimilarity *similarity;
}
- (LCHits *) search: (LCQuery *) query;
- (LCHits *) search: (LCQuery *) query
			 filter: (LCFilter *) filter;
- (LCHits *) search: (LCQuery *) query sort: (LCSort *) sort;
- (LCHits *) search: (LCQuery *) query 
             filter: (LCFilter *) filter sort: (LCSort *) sort;
- (LCTopFieldDocs *) searchQuery: (LCQuery *) query filter: (LCFilter *) filter 
					maximum: (int) n sort: (LCSort *) sort;
- (void) search: (LCQuery *) query
   hitCollector: (LCHitCollector *) results;
- (void) searchQuery: (LCQuery *) query filter: (LCFilter *) filter 
   hitCollector: (LCHitCollector *) results;
- (LCTopDocs *) searchQuery: (LCQuery *) query filter: (LCFilter *) filter maximum: (int) n;
- (void) setSimilarity: (LCSimilarity *) similarity;
- (LCSimilarity *) similarity;
- (LCExplanation *) explainQuery: (LCQuery *) query document: (int) doc;
@end

@interface LCSearcher (LCProtected)
- (id <LCWeight>) createWeight: (LCQuery *) query;
@end

#endif /* __LUCENE_SEARCH_SEARCHER__ */
