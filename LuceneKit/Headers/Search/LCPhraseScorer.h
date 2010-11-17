#ifndef __LUCENE_SEARCH_PHRASE_SCORER__
#define __LUCENE_SEARCH_PHRASE_SCORER__

#include "LCScorer.h"
#include "LCWeight.h"

@class LCPhraseQueue;
@class LCPhrasePositions;
@class LCSimilarity;
@class LCExplanation;

@interface LCPhraseScorer: LCScorer
{
	id <LCWeight> weight;
	NSData *norms;
	float value;
	
	BOOL firstTime;
	BOOL more;
	LCPhraseQueue *pq;
	LCPhrasePositions *first, *last;
	
	float freq;
}

- (id) initWithWeight: (id <LCWeight>) weight termPositions: (NSArray *) tps
			positions: (NSArray *) similarity: (LCSimilarity *) similarity;
- (int) document;
- (BOOL) next;
- (BOOL) doNext;
- (float) score;
- (BOOL) skipTo: (int) target;
- (float) phraseFrequency;
- (void) sort;
- (void) pqToList;
- (void) firstToLast;
- (LCExplanation *) explain: (int) doc;


@end

#endif /* __LUCENE_SEARCH_PHRASE_SCORER__ */
