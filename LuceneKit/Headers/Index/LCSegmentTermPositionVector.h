#ifndef __LUCENE_INDEX_SEGMENT_TERM_POSITION_VECTOR__
#define __LUCENE_INDEX_SEGMENT_TERM_POSITION_VECTOR__

#include "LCSegmentTermVector.h"
#include "LCTermPositionVector.h"

@interface LCSegmentTermPositionVector: LCSegmentTermVector <LCTermPositionVector>
{
	NSArray *positions; // array of NSArray of NSNumber (2D array)
	NSArray *offsets; // array of NSArray of LCTermVectorOffsetInfo (2D array)
}

- (id) initWithField: (NSString *) field
               terms: (NSArray *) terms
		   termFreqs: (NSArray *) termFreqs
           positions: (NSArray *) positions
			 offsets: (NSArray *) offsets;

@end

#endif /* __LUCENE_INDEX_SEGMENT_TERM_POSITION_VECTOR__ */
