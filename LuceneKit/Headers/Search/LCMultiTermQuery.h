#ifndef __LUCENE_SEARCH_MULTI_TERM_QUERY__
#define __LUCENE_SEARCH_MULTI_TERM_QUERY__

#include "LCQuery.h"

@class LCTerm;
@class LCFilteredTermEnumerator;
@class LCIndexReader;

@interface LCMultiTermQuery: LCQuery
{
	LCTerm *term;
}

- (id) initWithTerm: (LCTerm *) term;
- (LCTerm *) term;
- (LCFilteredTermEnumerator *) enumerator: (LCIndexReader *) reader;

@end

#endif /* __LUCENE_SEARCH_MULTI_TERM_QUERY__ */
