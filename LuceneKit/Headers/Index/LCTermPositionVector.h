#ifndef __LUCENE_INDEX_TERM_POSITION_VECTOR__
#define __LUCENE_INDEX_TERM_POSITION_VECTOR__

#include "LCTermFreqVector.h"

/** Extends <code>TermFreqVector</code> to provide additional information about
*  positions in which each of the terms is found. A TermPositionVector not necessarily
* contains both positions and offsets, but at least one of these arrays exists.
*/
@protocol LCTermPositionVector <LCTermFrequencyVector>

/** Returns an array of positions in which the term is found.
*  Terms are identified by the index at which its number appears in the
*  term String array obtained from the <code>indexOf</code> method.
*  May return null if positions have not been stored.
*/
// NSArray of NSNumber
- (NSArray *) termPositions: (int) index;

    /**
	* Returns an array of TermVectorOffsetInfo in which the term is found.
     * May return null if offsets have not been stored.
     * 
     * @see org.apache.lucene.analysis.Token
     * 
     * @param index The position in the array to get the offsets from
     * @return An array of TermVectorOffsetInfo objects or the empty list
     */ 
	// NSArray of LCTermVectorOffsetInfo
- (NSArray *) termOffsets: (int) index;

@end

#endif /* __LUCENE_INDEX_TERM_POSITION_VECTOR__ */
