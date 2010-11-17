#ifndef __LuceneKit_Search_TopFieldDocCollector__
#define __LuceneKit_Search_TopFieldDocCollector__

#include "LCTopDocCollector.h"

@class LCIndexReader;
@class LCSort;

@interface LCTopFieldDocCollector: LCTopDocCollector
- (id) initWithReader: (LCIndexReader *) reader
       sort: (LCSort *) sort
       maximalHits: (int) numHits;
@end

#endif /* __LuceneKit_Search_TopFieldDocCollector__ */
