#ifndef __LUCENE_SEARCH_CACHING_WRAPPER_FILTER__
#define __LUCENE_SEARCH_CACHING_WRAPPER_FILTER__

#include "LCFilter.h"

@class LCBitVector;
@class LCIndexReader;
@class LCFilter;

@interface LCCachingWrapperFilter: NSObject
{
	LCFilter *filter;
	NSDictionary *cache;
}

- (id) initWithFilter: (LCFilter *) filter;
- (LCBitVector *) bits: (LCIndexReader *) reader;
@end

#endif /* __LUCENE_SEARCH_CACHING_WRAPPER_FILTER__ */
