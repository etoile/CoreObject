#ifndef __LuceneKit_Search_TopDocCollector__
#define __LuceneKit_Search_TopDocCollector__

#include "LCHitCollector.h"

@class LCPriorityQueue;
@class LCTopDocs;

@interface LCTopDocCollector: LCHitCollector
{
	int numHits;
	float minScore;
	int totalHits;
	LCPriorityQueue *hq;
}

- (id) initWithMaximalHits: (int) max;
- (id) initWithMaximalHits: (int) max queue: (LCPriorityQueue *) q;
- (int) totalHits;
- (LCTopDocs *) topDocs;

@end

#endif /* __LuceneKit_Search_TopDocCollector__ */
