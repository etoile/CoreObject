#ifndef __LUCENE_SEARCH_SCORER__
#define __LUCENE_SEARCH_SCORER__

#include <Foundation/Foundation.h>
#include "LCSimilarity.h"
#include "LCHitCollector.h"
#include "LCExplanation.h"

@interface LCScorer: NSObject
{
	LCSimilarity *similarity;
}
- (id) initWithSimilarity: (LCSimilarity *) si;
- (LCSimilarity *) similarity;
- (void) score: (LCHitCollector *) hc;
	/* Override by subclass */
- (BOOL) next;
- (int) document;
- (float) score;
- (BOOL) skipTo: (int) target;
- (LCExplanation *) explain: (int) doc;
@end

@interface LCScorer (LCProtected)
- (BOOL) score: (LCHitCollector *) hc maximalDocument: (int) max;
@end

#endif /* __LUCENE_SEARCH_SCORER__ */
