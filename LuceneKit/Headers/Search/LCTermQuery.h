#ifndef __LUCENE_SEARCH_TERM_QUERY_
#define __LUCENE_SEARCH_TERM_QUERY_

#include "LCQuery.h"

@class LCTerm;

@interface LCTermQuery: LCQuery
{
	LCTerm *term;
}
- (id) initWithTerm: (LCTerm *) term;
- (LCTerm *) term;
@end

#endif /* __LUCENE_SEARCH_TERM_QUERY_ */

