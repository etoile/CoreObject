#ifndef __LUCENE_SEARCH_HITS__
#define __LUCENE_SEARCH_HITS__

#include <Foundation/Foundation.h>
#include "LCWeight.h"

@class LCDocument;
@class LCSearcher;
@class LCFilter;
@class LCSort;
@class LCHitIterator;

@interface LCHitDocument: NSObject
{
	float score;
	int identifier;
	LCDocument *doc;
	
	LCHitDocument *next;
	LCHitDocument *prev;
}

- (id) initWithScore: (float) s identifier: (int) iden;
- (LCHitDocument *) prev;
- (void) setPrev: (LCHitDocument *) hitDocument;
- (LCHitDocument *) next;
- (void) setNext: (LCHitDocument *) hitDocument;
- (float) score;
- (int) identifier;
- (LCDocument *) document;
- (void) setDocument: (LCDocument *) document;
@end

@interface LCHits: NSObject
{
	id <LCWeight> weight;
	LCSearcher *searcher;
	LCFilter *filter;
	LCSort *sort;
	int length; // the total number of hits
	NSMutableArray *hitDocs; // cache of hits retrieved
	LCHitDocument *first; // head of LRU cache
	LCHitDocument *last; // tail of LRU cache
	int numDocs; // number cached
	int maxDocs; // max to cache
}

- (id) initWithSearcher: (LCSearcher *) s
				  query: (LCQuery *) q
				 filter: (LCFilter *) f;
- (id) initWithSearcher: (LCSearcher *) s
				  query: (LCQuery *) q
				 filter: (LCFilter *) f
				   sort: (LCSort *) o;
- (NSUInteger) count; /* LuceneKit: length() in lucene */
- (LCDocument *) document: (int) n;
- (float) score: (int) n;
- (int) identifier: (int) n;
- (LCHitIterator *) iterator;

@end

#endif /* __LUCENE_SEARCH_HITS__ */
