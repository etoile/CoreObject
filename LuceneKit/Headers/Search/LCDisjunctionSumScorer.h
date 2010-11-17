#ifndef __LUCENE_DISJUNCTION_SUM_SCORER__
#define __LUCENE_DISJUNCTION_SUM_SCORER__

#include "LCScorer.h"

@class LCScorerQueue;

@interface LCDisjunctionSumScorer: LCScorer
{
	int nrScorers;
	NSArray *subScorers;
	int minimumNrMatchers;
	LCScorerQueue *scorerQueue;
	int currentDoc;
	int nrMatchers;
	float currentScore;
}

- (id) initWithSubScorers: (NSArray *) subScorers
		minimumNrMatchers: (int) minimumNrMatchers;
- (id) initWithSubScorers: (NSArray *) subScorers;
- (BOOL) advanceAfterCurrent;
- (int) nrMatchers;

@end

#endif /* __LUCENE_DISJUNCTION_SUM_SCORER__ */
