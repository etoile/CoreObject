#include "LCSegmentTermDocs.h"
#include "LCSegmentTermEnum.h"
#include "LCTermInfosReader.h"
#include "LCIndexInput.h"
#include "LCBitVector.h"
#include "GNUstep.h"

@implementation LCSegmentTermDocuments

- (id) initWithSegmentReader: (LCSegmentReader *) p
{
	self = [super init];
	doc = 0;
	ASSIGN(parent, p);
	ASSIGNCOPY(freqStream, [parent freqStream]);
	ASSIGN(deletedDocs, [parent deletedDocs]);
	skipInterval = [[parent termInfosReader] skipInterval];
	return self;
}

- (void) dealloc
{
	DESTROY(freqStream);
	DESTROY(skipStream);
	DESTROY(deletedDocs);
	DESTROY(parent);
	[super dealloc];
}

- (void) seekTerm: (LCTerm *) term
{
	LCTermInfo *ti = [[parent termInfosReader] termInfo: term];
	[self seekTermInfo: ti];
}

- (void) seekTermEnumerator: (LCTermEnumerator *) termEnum
{
	LCTermInfo *ti;
    
    // use comparison of fieldinfos to verify that termEnum belongs to the same segment as this SegmentTermDocs
	if ([termEnum isKindOfClass: [LCSegmentTermEnumerator class]] &&
		[(LCSegmentTermEnumerator *)termEnum fieldInfos] == [parent fieldInfos])
		// optimized case
		ti = [(LCSegmentTermEnumerator *)termEnum termInfo];
    else                                          // punt case
		ti = [[parent termInfosReader] termInfo: [termEnum term]];
	
    [self seekTermInfo: ti];
}

- (void) seekTermInfo: (LCTermInfo *) ti
{
    count = 0;
    if (ti == nil) {
		df = 0;
    } else {
		df = [ti documentFrequency];
		doc = 0;
		skipDoc = 0;
		skipCount = 0;
		numSkips = df / skipInterval;
		freqPointer = [ti freqPointer];
		proxPointer = [ti proxPointer];
		skipPointer = freqPointer + [ti skipOffset];
		[freqStream seekToFileOffset: freqPointer];
		haveSkipped = NO;
    }
}

- (void) close
{
    [freqStream close];
    if (skipStream != nil)
		[skipStream close];
}

- (long) document
{
	return doc;
}

- (long) frequency
{
	return freq;
}

- (void) skippingDoc
{
}

- (BOOL) hasNextDocument
{
    while (YES) {
		if (count == df)
			return NO;
		
		long docCode = [freqStream readVInt];
		doc += (docCode >> 1) & 0x7fffffff; //doc += docCode >>> 1;  // shift off low bit
		if ((docCode & 1) != 0)			  // if low bit is set
			freq = 1;				  // freq is one
		else
			freq = [freqStream readVInt];		  // else read freq
		
		count++;
		
		if (deletedDocs ==  nil|| ![deletedDocs bit: doc])
			break;
		[self skippingDoc];
    }
    return YES;
}

/** Optimized implementation. */
- (int) readDocuments: (NSMutableArray *) docs frequency: (NSMutableArray *) freqs size: (int) size
{
    int length = size;
    int i = 0;
    while (i < length && count < df) {
		
		// manually inlined call to next() for speed
		long docCode = [freqStream readVInt];
		doc += (docCode >> 1) & 0x7fffffff; //doc += docCode >>> 1;	  // shift off low bit
		if ((docCode & 1) != 0)			  // if low bit is set
			freq = 1;				  // freq is one
		else
			freq = [freqStream readVInt];		  // else read freq
		count++;
		
		if (deletedDocs == nil|| ![deletedDocs bit: doc]) {
			if (i < [docs count]) {
				[docs replaceObjectAtIndex: i withObject: [NSNumber numberWithLong: doc]];
				[freqs replaceObjectAtIndex: i withObject: [NSNumber numberWithLong: freq]];
			}
			else
			{
				[docs addObject: [NSNumber numberWithLong: doc]];
				[freqs addObject: [NSNumber numberWithLong: freq]];
			}
			++i;
		}
    }
    return i;
}

/** Overridden by SegmentTermPositions to skip in prox stream. */
- (void) skipProx: (long) proxPointer
{
}

/** Optimized implementation. */
- (BOOL) skipTo: (int) target
{
    if (df >= skipInterval) {                      // optimized case
		
		if (skipStream == nil)
			ASSIGNCOPY(skipStream, freqStream);
		
		if (!haveSkipped) {                          // lazily seek skip stream
			[skipStream seekToFileOffset: skipPointer];
			haveSkipped = YES;
		}
		
		// scan skip data
		int lastSkipDoc = skipDoc;
		long lastFreqPointer = [freqStream offsetInFile];
		long lastProxPointer = -1;
		int numSkipped = -1 - (count % skipInterval);
		
		while (target > skipDoc) {
			lastSkipDoc = skipDoc;
			lastFreqPointer = freqPointer;
			lastProxPointer = proxPointer;
			
			if (skipDoc != 0 && skipDoc >= doc)
				numSkipped += skipInterval;
			
			if(skipCount >= numSkips)
				break;
			
			skipDoc += [skipStream readVInt];
			freqPointer += [skipStream readVInt];
			proxPointer += [skipStream readVInt];
			
			skipCount++;
		}
		
		// if we found something to skip, then skip it
		if (lastFreqPointer > [freqStream offsetInFile]) {
			[freqStream seekToFileOffset: lastFreqPointer];
			[self skipProx: lastProxPointer];
			
			doc = lastSkipDoc;
			count += numSkipped;
		}
		
    }
	
    // done skipping, now just scan
    do {
		if (![self hasNextDocument])
			return NO;
    } while (target > doc);
    return YES;
}

@end
