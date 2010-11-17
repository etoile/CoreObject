#ifndef __LUCENE_SEARCH_SIMILARITY_DELEGATOR__
#define __LUCENE_SEARCH_SIMILARITY_DELEGATOR__

#include "LCSimilarity.h"

@interface LCSimilarityDelegator: LCSimilarity
{
	LCSimilarity *delegee;
}

- (id) initWithSimilarity: (LCSimilarity *) similarity;

@end
#endif /* __LUCENE_SEARCH_SIMILARITY_DELEGATOR__ */
