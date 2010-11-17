#ifndef __LUCENE_INDEX_TERM_INFOS_READER__
#define __LUCENE_INDEX_TERM_INFOS_READER__

#include <Foundation/Foundation.h>
#include "LCFieldInfos.h"
#include "LCSegmentTermEnum.h"
#include "LCTerm.h"

@interface LCTermInfosReader: NSObject
{
	id <LCDirectory> directory;
	NSString *segment;
	LCFieldInfos *fieldInfos;
	LCSegmentTermEnumerator *origEnum;
	unsigned long long size;
	
	NSMutableArray *indexTerms; // LCTerm
	NSMutableArray *indexInfos;  // LCTermInfo
	NSMutableArray *indexPointers; // NSNumber int
	
	LCSegmentTermEnumerator *indexEnum;
}

- (id) initWithDirectory: (id <LCDirectory>) dir
				 segment: (NSString *) seg
			  fieldInfos: (LCFieldInfos *) fis;
- (int) skipInterval;
- (void) close;
- (long) size;
- (LCTermInfo *) termInfo: (LCTerm *) term;
- (LCTerm *) termAtPosition: (int) position;
- (long) positionOfTerm: (LCTerm *) term;
- (LCSegmentTermEnumerator *) termEnumerator;
- (LCSegmentTermEnumerator *) termEnumeratorWithTerm: (LCTerm *) term;

@end

#endif /* __LUCENE_INDEX_TERM_INFOS_READER__ */
