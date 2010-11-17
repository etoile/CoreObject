#ifndef __LUCENE_SEARCH_RANGE_QUERY_
#define __LUCENE_SEARCH_RANGE_QUERY_

#include "LCQuery.h"

@class LCTerm;

@interface LCRangeQuery: LCQuery
{
  LCTerm *lowerTerm;
  LCTerm *upperTerm;
  BOOL inclusive;
}
- (id) initWithLowerTerm: (LCTerm *) lower upperTerm: (LCTerm *) upper
		inclusive: (BOOL) incl;
- (NSString *) field;
- (LCTerm *) lowerTerm;
- (LCTerm *) upperTerm;
- (BOOL) isInclusive;

@end

#endif /* __LUCENE_SEARCH_RANGE_QUERY_ */

