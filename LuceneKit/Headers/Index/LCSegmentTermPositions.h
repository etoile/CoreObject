#ifndef __LUCENE_INDEX_SEGMENT_TERM_POSITIONS__
#define __LUCENE_INDEX_SEGMENT_TERM_POSITIONS__

#include "LCSegmentTermDocs.h"
#include "LCTermPositions.h"

@interface LCSegmentTermPositions: LCSegmentTermDocuments <LCTermPositions>
{
	LCIndexInput *proxStream;
	int proxCount;
	int position;
}

- (id) initWithSegmentReader: (LCSegmentReader *) p;


@end


#endif /* __LUCENE_INDEX_SEGMENT_TERM_POSITIONS__ */
