#ifndef __LUCENE_SEARCHER_PHRASE_QUERY__
#define __LUCENE_SEARCHER_PHRASE_QUERY__

#include "LCWeight.h"

@class LCIndexReader;

@interface LCPhraseWeight: NSObject <LCWeight>
{
	LCSearcher *searcher;
	float value;
	float idf;
	float queryNorm;
	float queryWeight;
}

- (id) initWithSearcher: (LCSearcher *) searcher;
- (LCQuery *) query;
- (float) value;
- (float) sumOfSquaredWeights;
- (void) normalize: (float) queryNorm;
- (LCScorer *) scorer: (LCIndexReader *) reader;
- (LCExplanation *) explain: (LCIndexReader *) doc: (int) doc;
- (id <LCWeight>) createWeight: (LCSearcher *) searcher;
@end

@interface LCPhraseQuery: LCQuery
{
	NSString *field;
	NSArray *terms;
	NSArray *positions;
	int slop;
}

- (void) setSlop: (int) s;
- (int) slop;
- (void) addTerm: (LCTerm *) term;
- (void) addTerm: (LCTerm *) term position: (int) position;
- (NSArray *) terms;
- (NSArray *) positions;

@end

#endif /* __LUCENE_SEARCHER_PHRASE_QUERY__ */
