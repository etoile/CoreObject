#include "LCSimilarityDelegator.h"
#include "GNUstep.h"

@implementation LCSimilarityDelegator

- (id) initWithSimilarity: (LCSimilarity *) s
{
	self = [self init];
	ASSIGN(delegee, s);
	return self;
}

- (void) dealloc
{
  DESTROY(delegee);
  [super dealloc];
}

- (float) lengthNorm: (NSString *) fieldName numberOfTerms: (int) numTerms
{
	return [delegee lengthNorm: fieldName numberOfTerms: numTerms];
}

- (float) queryNorm: (float) sumOfSquredWeights
{
	return [delegee queryNorm: sumOfSquredWeights];
}

- (float) termFrequencyWithFloat: (float) freq
{
	return [delegee termFrequencyWithFloat: freq];
}

- (float) sloppyFrequency: (int) distance
{
	return [delegee sloppyFrequency: distance];
}

- (float) inverseDocumentFrequency: (int) docFreq 
				 numberOfDocuments: (int) numDocs
{
	return [delegee inverseDocumentFrequency: docFreq
						   numberOfDocuments: numDocs];
}

- (float) coordination: (int) overlap max: (int) maxOverlap
{
	return [delegee coordination: overlap max: maxOverlap];
}

@end
