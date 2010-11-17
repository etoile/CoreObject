#include "LCTermInfosReader.h"
#include "GNUstep.h"

/** This stores a monotonically increasing set of <Term, TermInfo> pairs in a
* Directory.  Pairs are accessed either by Term or by ordinal position the
* set.  */
@interface LCTermInfosReader (LCPrivate)
- (LCSegmentTermEnumerator *) internalTermEnumerator;
- (void) ensureIndexIsRead;
- (int) indexOffset: (LCTerm *) term;
- (void) seekEnumerator: (int) indexOffset;
- (LCTermInfo *) scanEnumerator: (LCTerm *) term;
- (LCTerm *) scanEnumeratorAtPosition: (int) position;
@end

@implementation LCTermInfosReader

- (id) initWithDirectory: (id <LCDirectory>) dir
				 segment: (NSString *) seg
              fieldInfos: (LCFieldInfos *) fis
{
	self = [super init];
	ASSIGN(directory, dir);
	ASSIGN(segment, seg);
	ASSIGN(fieldInfos, fis);
	origEnum = [[LCSegmentTermEnumerator alloc] initWithIndexInput: [dir openInput: [segment stringByAppendingPathExtension: @"tis"]]
												  fieldInfos: fieldInfos
													 isIndex: NO];
	size = [origEnum size];
	indexEnum = [[LCSegmentTermEnumerator alloc] initWithIndexInput: [dir openInput: [segment stringByAppendingPathExtension: @"tii"]]
												   fieldInfos: fieldInfos
													  isIndex: YES];
	return self;
}

- (void) dealloc
{
	DESTROY(origEnum);
	DESTROY(indexEnum);
        DESTROY(directory);
        DESTROY(segment);
        DESTROY(fieldInfos);
	
	DESTROY(indexTerms);
	DESTROY(indexInfos);
	DESTROY(indexPointers);

	[super dealloc];
}

- (int) skipInterval
{
	return [origEnum skipInterval];
}

- (void) close
{
    if (origEnum != nil)
		[origEnum close];
    if (indexEnum != nil)
		[indexEnum close];
}

/** Returns the number of term/value pairs in the set. */
- (long) size
{
    return size;
}

- (LCSegmentTermEnumerator *) internalTermEnumerator
{
#if 0
    LCSegmentTermEnumerator *termEnum = (LCSegmentTermEnum *)enumerators.get();
    if (termEnum == nil) {
		termEnum = [self termEnumerator];
		[enumerators set: termEnum];
    }
    return termEnum;
#endif
    return [self termEnumerator];
}

- (void) ensureIndexIsRead
{
    if (indexTerms != nil)                       // index already read
		return;                                     // do nothing
													//    int indexSize = (int)[indexEnum size];        // otherwise read index
	
    ASSIGN(indexTerms, AUTORELEASE([[NSMutableArray alloc] init]));
    ASSIGN(indexInfos, AUTORELEASE([[NSMutableArray alloc] init]));
    ASSIGN(indexPointers, AUTORELEASE([[NSMutableArray alloc] init]));
	
    while([indexEnum hasNextTerm])
	{
		[indexTerms addObject: [indexEnum term]];
		[indexInfos addObject: [indexEnum termInfo]];
		[indexPointers addObject: [NSNumber numberWithLong: [indexEnum indexPointer]]];
	}
	
	[indexEnum close];
	DESTROY(indexEnum);
}

/** Returns the offset of the greatest index entry which is less than or equal to term.*/
- (int) indexOffset: (LCTerm *) term
{
    int lo = 0;					  // binary search indexTerms[]
    int hi = [indexTerms count] - 1;
	
    while (hi > lo) {
		int mid = (lo + hi) >> 1;
		NSComparisonResult delta = 
			[term compare: [indexTerms objectAtIndex: mid]];
		if (delta == NSOrderedAscending)
			hi = mid - 1;
		else if (delta == NSOrderedDescending)
			lo = mid + 1;
		else
			return mid;
    }
    return hi;
}

- (void) seekEnumerator: (int) indexOffset
{
	long index = [[indexPointers objectAtIndex: indexOffset] longValue];
	int pos = indexOffset * [[self internalTermEnumerator] indexInterval] - 1;
	//  LCTerm *t = [indexTerms objectAtIndex: indexOffset];
	//  LCTermInfo *ti = [indexInfos objectAtIndex: indexOffset];
	[[self internalTermEnumerator] seek: index
				 position: pos
					 term: [indexTerms objectAtIndex: indexOffset]
				 termInfo: [indexInfos objectAtIndex: indexOffset]];
}

/** Returns the TermInfo for a Term in the set, or null. */
- (LCTermInfo *) termInfo: (LCTerm *) term
{
    if (size == 0) return nil;
	
    [self ensureIndexIsRead];
	
    // optimize sequential access: first try scanning cached enum w/o seeking
    LCSegmentTermEnumerator *enumerator = [self internalTermEnumerator];
    if (([enumerator term] != nil) // term is at or past current
		&& (([enumerator prev] != nil && [term compare: [enumerator prev]] == NSOrderedDescending)
			|| [term compare: [enumerator term]] != NSOrderedAscending)) {
		int enumOffset = (int)([enumerator position]/[enumerator indexInterval])+1;
		if ([indexTerms count] == enumOffset	  // but before end of block
			|| [term compare: [indexTerms objectAtIndex: enumOffset]] == NSOrderedAscending)
			return [self scanEnumerator: term];			  // no need to seek
    }
	
    // random-access: must seek
    int index = [self indexOffset: term];
    /* LuceneKit: if term doesn't exist, return nil */
    if (index < 0) return nil;
    [self seekEnumerator: index];
    return [self scanEnumerator: term];
}

/** Scans within block for matching term. */
- (LCTermInfo *) scanEnumerator: (LCTerm *) term
{
    LCSegmentTermEnumerator *enumerator = [self internalTermEnumerator];
    [enumerator scanTo: term];
    
    if ([enumerator term] != nil && [term compare: [enumerator term]] == NSOrderedSame)
		return [enumerator termInfo];
    else
		return nil;
}

/** Returns the nth term in the set. */
- (LCTerm *) termAtPosition: (int) position
{
    if (size == 0) return nil;
	
    LCSegmentTermEnumerator *enumerator = [self internalTermEnumerator];
    if (enumerator != nil && [enumerator term] != nil &&
        position >= [enumerator position] &&
		position < ([enumerator position] + [enumerator indexInterval]))
		return [self scanEnumeratorAtPosition: position];		  // can avoid seek
	
    [self seekEnumerator: (position / [enumerator indexInterval])]; // must seek
    return [self scanEnumeratorAtPosition: position];
}

- (LCTerm *) scanEnumeratorAtPosition: (int) position
{
    LCSegmentTermEnumerator *enumerator = [self internalTermEnumerator];
    while([enumerator position] < position)
		if (![enumerator hasNextTerm])
			return nil;
	
    return [enumerator term];
}

/** Returns the position of a Term in the set or -1. */
- (long) positionOfTerm: (LCTerm *) term
{
    if (size == 0) return -1;
	
    [self ensureIndexIsRead];
    int indexOffset = [self indexOffset: term];
    [self seekEnumerator: indexOffset];
	
    LCSegmentTermEnumerator *enumerator = [self internalTermEnumerator];
    while([term compare: [enumerator term]] == NSOrderedDescending && [enumerator hasNextTerm]) {}
	
    if ([term compare: [enumerator term]] == NSOrderedSame)
		return [enumerator position];
    else
		return -1;
}

/** Returns an enumeration of all the Terms and TermInfos in the set. */
- (LCSegmentTermEnumerator *) termEnumerator
{
	id result = AUTORELEASE([origEnum copy]);
	return (LCSegmentTermEnumerator *)result;
}

/** Returns an enumeration of terms starting at or after the named term. */
- (LCSegmentTermEnumerator *) termEnumeratorWithTerm: (LCTerm *) term
{
	[self ensureIndexIsRead];
    LCSegmentTermEnumerator *enumerator = [self internalTermEnumerator];
    [self seekEnumerator: [self indexOffset: term]];
    [enumerator scanTo: term];
    return enumerator;
}

@end
