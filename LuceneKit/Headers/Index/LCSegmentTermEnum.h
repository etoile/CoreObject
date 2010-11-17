#ifndef __LUCENE_INDEX_SEGMENT_TERM_ENUM__
#define __LUCENE_INDEX_SEGMENT_TERM_ENUM__

#include "LCTermEnum.h"
#include "LCIndexInput.h"
#include "LCFieldInfos.h"
#include "LCTermBuffer.h"
#include "LCTermInfo.h"

@interface LCSegmentTermEnumerator: LCTermEnumerator <NSCopying>
{
	LCIndexInput *input;
	LCFieldInfos *fieldInfos;
	long long size;
	long long position;
	LCTermBuffer *termBuffer, *prevBuffer;
	LCTermBuffer *scratch; // used for scanning
	LCTermInfo *termInfo;
	
	int format;
	BOOL isIndex;
	long indexPointer;
	int indexInterval;
	unsigned int skipInterval;
	int formatM1SkipInterval;
}

- (id) initWithIndexInput: (LCIndexInput *) i
               fieldInfos: (LCFieldInfos *) fis
                  isIndex: (BOOL) isi;
- (void) seek: (long) pointer position: (int) p
         term: (LCTerm *) t termInfo: (LCTermInfo *) ti;
- (void) scanTo: (LCTerm *) term;
- (LCTerm *) prev;
- (void) setIndexInput: (LCIndexInput *) i;
- (void) setFieldInfos: (LCFieldInfos *) fi;
- (void) setSize: (long long) size;
- (void) setPosition: (long long) position;
- (void) setTermInfo: (LCTermInfo *) ti;
- (void) setTermBuffer: (LCTermBuffer *) tb;
- (void) setPrevBuffer: (LCTermBuffer *) pb;
- (void) setScratch: (LCTermBuffer *) s;
#if 0
- (void) setFormat: (int) f;
- (void) setIndexed: (BOOL) index;
- (void) setIndexPointer: (long) indexPointer;
- (void) setIndexInterval: (int) indexInterval;
- (void) setSkipInterval: (unsigned int) skipInterval;
- (void) setFormatM1SkipInterval: (int) formatM1SkipInterval;
#endif
- (LCTermInfo *) termInfo;
- (LCFieldInfos *) fieldInfos;
- (long long) size;
- (long) indexPointer;
- (long long) position;
- (unsigned int) skipInterval;
- (int) indexInterval;
- (long long) freqPointer;
- (long long) proxPointer;

@end

#endif /* __LUCENE_INDEX_SEGMENT_TERM_ENUM__ */
