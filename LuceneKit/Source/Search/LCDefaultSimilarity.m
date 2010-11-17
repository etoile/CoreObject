#include "LCDefaultSimilarity.h"
#include <math.h>

/** Expert: Default scoring implementation. */
@implementation LCDefaultSimilarity
/** Implemented as <code>1/sqrt(numTerms)</code>. */
- (float) lengthNorm: (NSString *) fileName
	   numberOfTerms: (int) numTerms
{
	return (float)(1.0 / sqrt(numTerms));
}

/** Implemented as <code>1/sqrt(sumOfSquaredWeights)</code>. */
- (float) queryNorm: (float) sumOfSquaredWeights
{
	return (float)(1.0 / sqrt(sumOfSquaredWeights));
}

/** Implemented as <code>sqrt(freq)</code>. */
- (float) termFrequencyWithFloat: (float) freq
{
	return (float)sqrt(freq);
}

/** Implemented as <code>1 / (distance + 1)</code>. */
- (float) sloppyFrequency: (int) distance
{
	return 1.0f / (distance + 1);
}

/** Implemented as <code>log(numDocs/(docFreq+1)) + 1</code>. */
- (float) inverseDocumentFrequency: (int) docFreq 
				 numberOfDocuments: (int) numDocs
{
	return (float)(log(numDocs/(double)(docFreq+1)) + 1.0);
}

/** Implemented as <code>overlap / maxOverlap</code>. */
- (float) coordination: (int) overlap max: (int) maxOverLap
{
	return (float)overlap / (float)maxOverLap;
}

@end
