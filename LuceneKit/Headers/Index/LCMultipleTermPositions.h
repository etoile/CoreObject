#ifndef __LUCENE_INDEX_MULTIPLE_TERM_POSITION__
#define __LUCENE_INDEX_MULTIPLE_TERM_POSITION__

#include <Foundation/Foundation.h>
#include "LCTermPositions.h"
#include "LCPriorityQueue.h"
#include "LCIndexReader.h"

@class LCTermPositionsQueue; // Private
@class LCIntQueue; //Private

@interface LCMultipleTermPositions: NSObject <LCTermPositions>
{
	int _doc;
	int _freq;
	LCTermPositionsQueue *_termPositionsQueue;
	LCIntQueue *_posList;
}

- (id) initWithIndexReader: (LCIndexReader *) indexReader
					 terms: (NSArray *) terms;
@end

#endif /* __LUCENE_INDEX_MULTIPLE_TERM_POSITION__ */
