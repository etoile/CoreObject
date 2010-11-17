#ifndef __LUCENE_SEARCH_TERM_SCORER__
#define __LUCENE_SEARCH_TERM_SCORER__

#include "LCScorer.h"
#include "LCWeight.h"
#include "LCTermDocs.h"

// static int SCORE_CACHE_SIZE = 32;


@interface LCTermScorer: LCScorer
{
	id <LCWeight> weight;
	id <LCTermDocuments> termDocs;
	NSData *norms;
	float weightValue;
	int doc;
	
	NSMutableArray *docs; // buffered doc numbers;
	NSMutableArray *freqs; // buffered term freqs;
	int pointer;
	int pointerMax;
	
	NSMutableArray *scoreCache;
}

- (id) initWithWeight: (id <LCWeight>) weight termDocuments: (id <LCTermDocuments>) td
		   similarity: (LCSimilarity *) similarity norms: (NSData *) norms;

@end

#endif /* __LUCENE_SEARCH_TERM_SCORER__ */
