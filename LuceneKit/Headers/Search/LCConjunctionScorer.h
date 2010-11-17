#ifndef __LUCENE_SEARCH_CONJUNCTION_SCORER__
#define __LUCENE_SEARCH_CONJUNCTION_SCORER__

#include "LCScorer.h"

@interface LCConjunctionScorer: LCScorer
{
	NSMutableArray *scorers;
	BOOL firstTime;
	BOOL more;
	float coord;
}

- (void) addScorer: (LCScorer *) scorer;
@end

#endif /* __LUCENE_SEARCH_CONJUNCTION_SCORER__ */
