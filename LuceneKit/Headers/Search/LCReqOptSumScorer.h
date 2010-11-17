#ifndef __LUCENE_SEARCH_REQ_OPT_SUM_SCORER__
#define __LUCENE_SEARCH_REQ_OPT_SUM_SCORER__

#include "LCScorer.h"

@interface LCReqOptSumScorer: LCScorer
{
	LCScorer *reqScorer;
	LCScorer *optScorer;
	BOOL firstTimeOptScorer;
}

- (id) initWithRequired: (LCScorer *) required optional: (LCScorer *) optional;

@end

#endif /* __LUCENE_SEARCH_REQ_OPT_SUM_SCORER__ */
