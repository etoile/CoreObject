#ifndef __LUCENE_INDEX_SEGMENT_TERM_DOCS__
#define __LUCENE_INDEX_SEGMENT_TERM_DOCS__

#include <Foundation/Foundation.h>
#include "LCTermDocs.h"
#include "LCSegmentReader.h"
#include "LCTermInfo.h"

@class LCIndexInput;
@class LCBitVector;

@interface LCSegmentTermDocuments: NSObject <LCTermDocuments>
{
	LCSegmentReader *parent;
	LCIndexInput *freqStream;
	int count;
	int df;
	LCBitVector *deletedDocs;
	long doc;
	long freq;
	
	int skipInterval;
	int numSkips;
	int skipCount;
	LCIndexInput *skipStream;
	long skipDoc;
	long long freqPointer;
	long long proxPointer;
	long long skipPointer;
	BOOL haveSkipped;
}

- (id) initWithSegmentReader: (LCSegmentReader *) p;
- (void) seekTermInfo: (LCTermInfo *) ti;
- (void) skippingDoc;
- (void) skipProx: (long) proxPointer;

@end

#endif /* __LUCENE_INDEX_SEGMENT_TERM_DOCS__ */
