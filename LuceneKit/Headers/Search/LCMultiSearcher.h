#ifndef __LUCENE_SEARCH_MULTI_SEARCHER__
#define __LUCENE_SEARCH_MULTI_SEARCHER__

#include "LCSearcher.h"

@class LCExplanation;
@class LCDocument;
@class LCTerm;

@interface LCMultiSearcher: LCSearcher
{
	NSArray *searchables;
	NSArray *starts;
	int maxDoc;
}

- (id) initWithSearchables: (NSArray *) searchables;
- (NSArray *) searchables;
- (NSArray *) starts;
- (void) close;
- (int) documentFrequency: (LCTerm *) term;
- (LCDocument *) document: (int) n;
- (int) searcherIndex: (int) n;
- (int) subSearcher: (int) n;
- (int) subDocument: (int) n;
- (int) maxDocument;
- (LCTopDocs *) search: (LCQuery *) query filter: (LCFilter *) filter
				 nDocs: (int) nDocs;
- (LCTopFieldDocs *) search: (LCQuery *) query filter: (LCFilter *) filter
					  nDocs: (int) nDocs sort: (LCSort *) sort;
- (void) search: (LCQuery *) query filter: (LCFilter *) filter
		results: (LCHitCollector *) results;
- (LCQuery *) rewrite: (LCQuery *) original;
- (LCExplanation *) explain: (LCQuery *) query doc: (int) doc;

@end

#endif /* __LUCENE_SEARCH_MULTI_SEARCHER__ */
