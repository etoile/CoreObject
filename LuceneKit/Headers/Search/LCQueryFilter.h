#ifndef __LUCENE_SEARCH_QUERY_FILTER__
#define __LUCENE_SEARCH_QUERY_FILTER__

#include "LCFilter.h"

@class LCQuery;

@interface LCQueryFilter: LCFilter
{
	LCQuery *query;
	NSMutableDictionary *cache;
}
/** Constructs a filter which only matches documents matching
* <code>query</code>.
*/
- (id) initWithQuery: (LCQuery *) query;
- (LCQuery *) query;

@end

#endif /* __LUCENE_SEARCH_QUERY_FILTER__ */
