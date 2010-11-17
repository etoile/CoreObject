#ifndef __LUCENE_SEARCH_MULTI_PHRASE_QUERY__
#define __LUCENE_SEARCH_MULTI_PHRASE_QUERY__

#include "LCWeight.h"

@class LCSearcher;

@interface LCMultiPhraseWeight: NSObject <LCWeight>
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
- (LCExplanation *) explain: (LCIndexReader *) reader doc: (int) doc;
- (LCQuery *) rewrite: (LCIndexReader *) reader;

@end

@interface LCMultiPhraseQuery: LCQuery
{
	NSString *field;
	NSArray *termArrays;
	NSArray *positions;
	int slop;
}

- (void) setSlop: (int) s;
- (int) slop;
- (void) addTerm: (LCTerm *) term;
- (void) addTerms: (NSArray *) terms;
- (void) addTerm: (LCTerm *) position: (int) position;
- (NSArray *) positions;
- (id <LCWeight>) createWeight: (LCSearcher *) searcher;
@end

#endif /* __LUCENE_SEARCH_MULTI_PHRASE_QUERY__ */
