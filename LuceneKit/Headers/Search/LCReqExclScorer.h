#ifndef __LUCENE_SEARCH_REQ_EXCL_SCORER__
#define __LUCENE_SEARCH_REQ_EXCL_SCORER__

#include "LCScorer.h"

@interface LCReqExclScorer: LCScorer
{
	LCScorer *reqScorer;
	LCScorer *exclScorer;
	BOOL firstTime;
}
- (id) initWithRequired: (LCScorer *) required  excluded: (LCScorer *) excluded;
@end

#endif /* __LUCENE_SEARCH_REQ_EXCL_SCORER__ */
