#include "LCSegmentTermEnum.h"
#include "LCTermInfosWriter.h"
#include "GNUstep.h"
#include <limits.h>

@implementation LCSegmentTermEnumerator

- (id) init
{
	self = [super init];
	position = -1;
	[self setTermBuffer: AUTORELEASE([[LCTermBuffer alloc] init])];
	[self setPrevBuffer: AUTORELEASE([[LCTermBuffer alloc] init])];
	ASSIGN(termInfo, AUTORELEASE([[LCTermInfo alloc] init]));
	indexPointer = 0;
	return self;
}

- (id) initWithIndexInput: (LCIndexInput *) i
			   fieldInfos: (LCFieldInfos *) fis
				  isIndex: (BOOL) isi;
{
	self = [self init];
	[self setIndexInput: i];
	[self setFieldInfos: fis];
	isIndex = isi;
	int firstInt = [input readInt];
	if (firstInt >= 0) {
		// original-format file, without explicit format version number
		format = 0;
		size = firstInt;
		
		// back-compatible settings
		indexInterval = 128;
		skipInterval = INT_MAX; //Integer.MAX_VALUE; // switch off skipTo optimization
		
    } else {
		// we have a format version number
		format = firstInt;
		
		// check that it is a format we can understand
		if (format < LCTermInfos_FORMAT)
		{
			NSLog(@"Unknown format version: %d", format);
			return nil;
		}
		
		size = [input readLong];                    // read the size
		
		if(format == -1){
			if (!isIndex) {
				indexInterval = [input readInt];
				formatM1SkipInterval = [input readInt];
			}
			// switch off skipTo optimization for file format prior to 1.4rc2 in order to avoid a bug in 
			// skipTo implementation of these versions
			skipInterval = INT_MAX; // Integer.MAX_VALUE;
		}
		else{
			indexInterval = [input readInt];
			skipInterval = [input readInt];
		}
    }
	return self;
	
}

- (void) dealloc
{
	DESTROY(termInfo);
	DESTROY(input);
	DESTROY(fieldInfos);
	DESTROY(termBuffer);
	DESTROY(prevBuffer);
	DESTROY(scratch);
	[super dealloc];
}

- (void) seek: (long) pointer position: (int) p
         term: (LCTerm *) t termInfo: (LCTermInfo *) ti
{
	[input seekToFileOffset: pointer];
	position = p;
	[termBuffer setTerm: t];
	[termInfo setTermInfo: ti];
}

/** Increments the enumeration to the next element.  True if one exists.*/
- (BOOL) hasNextTerm
{
    if (position++ >= size-1)
    {
		return NO;
    }
	
    [prevBuffer setTerm: termBuffer];
    [termBuffer read: input fieldInfos: fieldInfos];
	
    long intValue = [input readVInt];
    [termInfo setDocumentFrequency: intValue];	  // read doc freq
    long long longValue = [input readVLong];
    [termInfo setFreqPointer: longValue + [termInfo freqPointer]];	  // read freq pointer
    [termInfo setProxPointer: [input readVLong] + [termInfo proxPointer]];	  // read prox pointer
    
    if(format == -1){
		//  just read skipOffset in order to increment  file pointer; 
		// value is never used since skipTo is switched off
		if (!isIndex) {
			if ([termInfo documentFrequency] > formatM1SkipInterval) {
				[termInfo setSkipOffset: [input readVInt]]; 
			}
		}
    }
    else{
		if ([termInfo documentFrequency] >= skipInterval) 
			[termInfo setSkipOffset: [input readVInt]];
    }
    
    if (isIndex)
    {
		long long longValue = [input readVLong];
		indexPointer += longValue;
		//      indexPointer += [input readVLong];	  // read index pointer
    }
	
    return YES;
}

/** Optimized scan, without allocating new terms. */
- (void) scanTo: (LCTerm *) term
{
	if (scratch == nil)
		ASSIGN(scratch, AUTORELEASE([[LCTermBuffer alloc] init]));
	[scratch setTerm: term];
	while (([scratch compare: termBuffer] == NSOrderedDescending) && [self hasNextTerm]) {}
}

/** Returns the current Term in the enumeration.
Initially invalid, valid after next() called for the first time.*/
- (LCTerm *) term
{
    return AUTORELEASE([termBuffer copy]);
}

/** Returns the previous Term enumerated. Initially null.*/
- (LCTerm *) prev
{
    return AUTORELEASE([prevBuffer copy]);
}

/** Returns the current TermInfo in the enumeration.
Initially invalid, valid after next() called for the first time.*/
- (LCTermInfo *) termInfo
{
	return AUTORELEASE([[LCTermInfo alloc] initWithTermInfo: termInfo]);
}

/** Sets the argument to the current TermInfo in the enumeration.
Initially invalid, valid after next() called for the first time.*/
- (void) setTermInfo: (LCTermInfo *) ti
{
	[termInfo setTermInfo: ti];
}

/** Returns the docFreq from the current TermInfo in the enumeration.
Initially invalid, valid after next() called for the first time.*/
- (long) documentFrequency
{
    return [termInfo documentFrequency];
}

/* Returns the freqPointer from the current TermInfo in the enumeration.
Initially invalid, valid after next() called for the first time.*/
- (long long) freqPointer
{
    return [termInfo freqPointer];
}

/* Returns the proxPointer from the current TermInfo in the enumeration.
Initially invalid, valid after next() called for the first time.*/
- (long long) proxPointer
{
    return [termInfo proxPointer];
}

/** Closes the enumeration to further activity, freeing resources. */
- (void) close
{
    [input close];
}

- (void) setIndexInput: (LCIndexInput *) i
{
	ASSIGN(input, i);
}

- (void) setTermBuffer: (LCTermBuffer *) tb
{
	ASSIGN(termBuffer, tb);
}

- (void) setPrevBuffer: (LCTermBuffer *) pb
{
	ASSIGN(prevBuffer, pb);
}

- (void) setScratch: (LCTermBuffer *) s
{
	ASSIGN(scratch, s);
}

- (void) setSize: (long long) s
{
	size = s;
}

- (void) setPosition: (long long ) p
{
	position = p;
}

- (void) setFormat: (int) f
{
	format = f;
}

- (void) setIndexed: (BOOL) index
{
	isIndex = index;
}

- (void) setIndexPointer: (long) p
{
	indexPointer = p;
}

- (void) setIndexInterval: (int) i
{
	indexInterval = i;
}

- (void) setSkipInterval: (unsigned int) skip
{
	skipInterval = skip;
}

- (void) setFormatM1SkipInterval: (int) formatM1
{
	formatM1SkipInterval = formatM1;
}

- (void) setFieldInfos: (LCFieldInfos *) fi
{
	ASSIGN(fieldInfos, fi);
}

- (LCFieldInfos *) fieldInfos
{
	return fieldInfos;
}

- (long long) size
{
	return size;
}

- (long) indexPointer
{
	return indexPointer;
}

- (int) indexInterval
{
	return indexInterval;
}

- (unsigned int) skipInterval
{
	return skipInterval;
}

- (long long) position
{
	return position;
}

- (id) copyWithZone: (NSZone *) zone
{
	LCSegmentTermEnumerator *clone = [[LCSegmentTermEnumerator allocWithZone: zone] init];
	
	[clone setIndexInput: AUTORELEASE([input copy])];
	[clone setFieldInfos: fieldInfos];
	[clone setSize: size];
	[clone setPosition: position];
	[clone setTermInfo: AUTORELEASE([termInfo copy])];
	[clone setTermBuffer: AUTORELEASE([termBuffer copy])];
	[clone setPrevBuffer: AUTORELEASE([prevBuffer copy])];
	[clone setScratch: nil];
	[clone setFormat: format];
	[clone setIndexed: isIndex];
	[clone setIndexPointer: indexPointer];
	[clone setIndexInterval: indexInterval];
	[clone setSkipInterval: skipInterval];
	[clone setFormatM1SkipInterval: formatM1SkipInterval];
	
	return clone;
}

@end
