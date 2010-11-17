#ifndef __LUCENE_SEARCH_SIMILARITY__
#define __LUCENE_SEARCH_SIMILARITY__

#include <Foundation/Foundation.h>

//static float *NORM_TABLE = NULL;

//@class LCSearcher;
@class LCTerm;
@class LCSearcher;

@interface LCSimilarity: NSObject
{
}

+ (void) setDefaultSimilarity: (LCSimilarity *) similarity;
+ (LCSimilarity *) defaultSimilarity;
+ (float) decodeNorm: (char) b;
+ (float *) normDecoder;
	/* override by subclass */
- (float) lengthNorm: (NSString *) fieldName numberOfTerms: (int) numTerms;
	/* override by subclass */
- (float) queryNorm: (float) sumOfSquredWeights;
+ (char) encodeNorm: (float) f;
- (float) termFrequencyWithInt: (int) freq;
- (float) sloppyFrequency: (int) distance;
- (float) termFrequencyWithFloat: (float) freq;
- (float) inverseDocumentFrequencyWithTerm: (LCTerm *) term
								  searcher: (LCSearcher *) searcher;
- (float) inverseDocumentFrequencyWithTerms: (NSArray *) terms
								   searcher: (LCSearcher *) searcher;
	/* override by subclass */
- (float) inverseDocumentFrequency: (int) docFreq 
				 numberOfDocuments: (int) numDocs;
	/* override by subclass */
- (float) coordination: (int) overlap max: (int) maxOverlap;

@end
#endif /* __LUCENE_SEARCH_SIMILARITY__ */
