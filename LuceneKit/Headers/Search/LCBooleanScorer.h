#ifndef __LUCENE_SEARCH_BOOLEAN_SCORER2__
#define __LUCENE_SEARCH_BOOLEAN_SCORER2__

#include "LCScorer.h"

/* LuceneKit: This is actuall the BooleanScorer2 in lucene */

@class LCBooleanScorer;
@class LCCoordinator;

@interface LCBooleanScorer: LCScorer
{
	NSMutableArray *requiredScorers;
	NSMutableArray *optionalScorers;
	NSMutableArray *prohibitedScorers;
	
	LCCoordinator *coordinator;
	LCScorer *countingSumScorer;
	
	int minNrShouldMatch;
}

- (id) initWithSimilarity: (LCSimilarity *) similarity;
- (id) initWithSimilarity: (LCSimilarity *) similarity
	minimumNumberShouldMatch: (int) min;
- (void) addScorer: (LCScorer *) scorer
		  required: (BOOL) required
		prohibited: (BOOL) prohibited;
@end

#endif /* __LUCENE_SEARCH_BOOLEAN_SCORER2__ */
