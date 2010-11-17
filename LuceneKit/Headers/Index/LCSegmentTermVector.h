#ifndef __LUCENE_INDEX_SEGMENT_TERM_VECTOR__
#define __LUCENE_INDEX_SEGMENT_TERM_VECTOR__

#include "LCTermFreqVector.h"

@interface LCSegmentTermVector: NSObject <LCTermFrequencyVector>
{
	NSString *field;
	NSArray *terms; // NSArray of NSString
	NSArray *termFreqs; // NSArray of NSNumber
}

- (id) initWithField: (NSString *) field
               terms: (NSArray *) terms
           termFreqs: (NSArray *) termFreqs;
@end

#endif /* __LUCENE_INDEX_SEGMENT_TERM_VECTOR__ */
