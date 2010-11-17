#include "LCMultiReader.h"
#include "LCSegmentMergeQueue.h"
#include "LCSegmentMergeInfo.h"
#include "LCSegmentReader.h"
#include "GNUstep.h"

/** An IndexReader which reads multiple indexes, appending their content.
*
* @version $Id$
*/
@interface LCMultiReader (LCPrivate)
- (void) initialize: (NSArray *) subReaders;
- (int) readerIndex: (int) n;
@end

@implementation LCMultiReader

- (id) init
{
	self = [super init];
	normsCache = [[NSMutableDictionary alloc] init];
	maxDoc = 0;
	numDocs = -1;
	hasDeletions = NO;
	return self;
}

/**
* <p>Construct a MultiReader aggregating the named set of (sub)readers.
 * Directory locking for delete, undeleteAll, and setNorm operations is
 * left to the subreaders. </p>
 * <p>Note that all subreaders are closed if this Multireader is closed.</p>
 * @param subReaders set of (sub)readers
 * @throws IOException
 */
- (id) initWithReaders: (NSArray *) r
{
	self = [self init];
	[super initWithDirectory: ([r count] == 0) ? nil : [(LCIndexReader *)[r objectAtIndex: 0] directory]];
	[self initialize: r];
	return self;
}

/** Construct reading the named set of readers. */
- (id) initWithDirectory: (id <LCDirectory>) dir
			segmentInfos: (LCSegmentInfos *) sis
				   close: (BOOL) close
	             readers: (NSArray *) sr
{
	self = [self init];
	[super initWithDirectory: dir
				segmentInfos: sis
			  closeDirectory: close];
	[self initialize: sr];
	return self;
}

- (void) dealloc
{
	DESTROY(normsCache);
	DESTROY(subReaders);
	DESTROY(starts);
	DESTROY(ones);
	[super dealloc];
}

- (void) initialize: (NSArray *) sr
{
	ASSIGN(subReaders, sr);
	starts = [[NSMutableArray alloc] init]; // build starts array
	int i;
	for (i = 0; i < [subReaders count]; i++) {
		[starts addObject: [NSNumber numberWithInt: maxDoc]];
		maxDoc += [[subReaders objectAtIndex: i] maximalDocument];      // compute maxDocs
		
		if ([[subReaders objectAtIndex: i] hasDeletions])
			hasDeletions = YES;
	}
	[starts addObject: [NSNumber numberWithInt: maxDoc]];
}


/** Return an array of term frequency vectors for the specified document.
*  The array contains a vector for each vectorized field in the document.
*  Each vector vector contains term numbers and frequencies for all terms
*  in a given vectorized field.
*  If no such fields existed, the method returns null.
*/
- (NSArray *) termFrequencyVectors: (int) n
{
	int i = [self readerIndex: n];        // find segment num
	return [[subReaders objectAtIndex: i] termFrequencyVectors: (n - [[starts objectAtIndex: i] intValue])]; // dispatch to segment
}

- (id <LCTermFrequencyVector>) termFrequencyVector: (int) n field: (NSString *) field
{
	int i = [self readerIndex: n];       // find segment num
	return [[subReaders objectAtIndex: i] termFrequencyVector: (n - [[starts objectAtIndex: i] intValue])
												   field: field];
}

- (int) numberOfDocuments
{
    if (numDocs == -1) {        // check cache
		int n = 0;                // cache miss--recompute
		int i;
		for (i = 0; i < [subReaders count]; i++)
			n += [[subReaders objectAtIndex: i] numberOfDocuments]; // sum from readers
		numDocs = n;
    }
    return numDocs;
}

- (int) maximalDocument
{
    return maxDoc;
}

- (LCDocument *) document: (int) n
{
	int i = [self readerIndex: n];        // find segment num
	return [[subReaders objectAtIndex: i] document: (n - [[starts objectAtIndex: i] intValue])]; // dispatch to segment
}

- (BOOL) isDeleted: (int) n
{
	int i = [self readerIndex: n];        // find segment num
	return [[subReaders objectAtIndex: i] isDeleted: (n - [[starts objectAtIndex: i] intValue])]; // dispatch to segment
}

- (BOOL) hasDeletions
{
	return hasDeletions; 
}

- (void) doDelete: (int) n
{
    numDocs = -1;                             // invalidate cache
    int i = [self readerIndex: n];        // find segment num
    [(LCIndexReader *)[subReaders objectAtIndex: i] deleteDocument: (n - [[starts objectAtIndex: i] intValue])]; // dispatch to segment
    hasDeletions = YES;
}

- (void) doUndeleteAll
{
	int i;
	for (i = 0; i < [subReaders count]; i++)
		[[subReaders objectAtIndex: i] undeleteAll];
    hasDeletions = NO;
	numDocs = -1; // invalidate cache
}

- (int) readerIndex: (int) n  // find reader for doc n:
{
    int lo = 0;                                      // search starts array
    int hi = [subReaders count] - 1;                  // for first element less
	
    while (hi >= lo) {
		int mid = (lo + hi) >> 1;
		int midValue = [[starts objectAtIndex: mid] intValue];
		if (n < midValue)
			hi = mid - 1;
		else if (n > midValue)
			lo = mid + 1;
		else {                                      // found a match
			while (mid+1 < [subReaders count] && [[starts objectAtIndex: (mid+1)] intValue] == midValue) {
				mid++;                                  // scan to last match
			}
			return mid;
		}
    }
    return hi;
}

- (BOOL) hasNorms: (NSString *) field
{
	int i;
	for (i = 0; i < [subReaders count]; i++)
	{
		if ([[subReaders objectAtIndex: i] hasNorms: field]) return YES;
	}
	return NO;
}

- (NSData *) fakeNorms
{
	if (ones == nil)
		ASSIGN(ones, [LCSegmentReader createFakeNorms: [self maximalDocument]]);
	return ones;
}

- (NSData *) norms: (NSString *) field
{
	NSMutableData *bytes = [normsCache objectForKey: field];
	if (bytes != nil)
		return bytes;          // cache hit
	if (![self hasNorms: field])
		return [self fakeNorms];
	
	bytes = [[NSMutableData alloc] init];
	int i;
	for (i = 0; i < [subReaders count]; i++)
		[[subReaders objectAtIndex: i] setNorms: field bytes: bytes offset: [[starts objectAtIndex: i] intValue]];
	[normsCache setObject: bytes forKey: field]; // update cache
	return AUTORELEASE(bytes);
}

- (void) setNorms: (NSString *) field 
            bytes: (NSMutableData *) result offset: (int) offset
{
	NSData *bytes = [normsCache objectForKey: field];
	if ((bytes == nil) && (![self hasNorms: field]))
		bytes = [self fakeNorms];
	if (bytes != nil)                            // cache hit
	{
		NSRange r = NSMakeRange(offset, [self maximalDocument]);
		[result replaceBytesInRange: r withBytes: [bytes bytes]];
	}
	
	int i;
	for (i = 0; i < [subReaders count]; i++)      // read from segments
		[[subReaders objectAtIndex: i] setNorms: field bytes: result offset: offset + [[starts objectAtIndex: i] intValue]];
}

- (void) doSetNorm: (int) n field: (NSString *) field charValue: (char) value
{
	[normsCache removeObjectForKey: field]; // clear cache
	int i = [self readerIndex: n]; // find segment num
	[[subReaders objectAtIndex: i] setNorm: (n-[[starts objectAtIndex: i] intValue]) field: field charValue: value]; // dispatch
}

- (LCTermEnumerator *) termEnumerator
{
	return AUTORELEASE([[LCMultiTermEnumerator alloc] initWithReaders: subReaders
														 starts: starts
														   term: nil]);
}

- (LCTermEnumerator *) termEnumeratorWithTerm: (LCTerm *) term
{
	return AUTORELEASE([[LCMultiTermEnumerator alloc] initWithReaders: subReaders
														 starts: starts
														   term: term]);
}

- (long) documentFrequency: (LCTerm *) t
{
	int total = 0;          // sum freqs in segments
	int i;
	for (i = 0; i < [subReaders count]; i++)
	{
		total += [[subReaders objectAtIndex: i] documentFrequency: t];
	}
	return total;
}

- (id <LCTermDocuments>) termDocuments
{
	return AUTORELEASE([[LCMultiTermDocuments alloc] initWithReaders: subReaders
														 starts: starts]);
}

- (id <LCTermPositions>) termPositions
{
	return AUTORELEASE([[LCMultiTermPositions alloc] initWithReaders: subReaders
															  starts: starts]);
}

- (void) doCommit
{
	int i;
	for (i = 0; i < [subReaders count]; i++)
		[[subReaders objectAtIndex: i] commit];
}

- (void) doClose
{
	int i;
	for (i = 0; i < [subReaders count]; i++)
		[[subReaders objectAtIndex: i] close];
}

/**
* @see IndexReader#getFieldNames(IndexReader.FieldOption)
 */
- (NSArray *) fieldNames: (LCFieldOption) fieldOption
{
    // maintain a unique set of field names
    NSMutableSet *fieldSet = [[NSMutableSet alloc] init];
    int i;
    for (i = 0; i < [subReaders count]; i++) {
		LCIndexReader *reader = [subReaders objectAtIndex: i];
		[fieldSet addObjectsFromArray: [reader fieldNames: fieldOption]];
    }
    AUTORELEASE(fieldSet);
    return [fieldSet allObjects];
}

@end

@implementation LCMultiTermEnumerator

- (id) initWithReaders: (NSArray *) readers
				starts: (NSArray *) starts
                  term: (LCTerm *) t
{
	self = [super init];
	queue = [(LCSegmentMergeQueue *)[LCSegmentMergeQueue alloc] initWithSize: [readers count]];
	int i;
	for (i = 0; i < [readers count]; i++) {
		LCIndexReader *reader = [readers objectAtIndex: i];
		LCTermEnumerator *termEnum;
		
		if (t != nil) {
			termEnum = [reader termEnumeratorWithTerm: t];
		} else
			termEnum = [reader termEnumerator];
		
		LCSegmentMergeInfo *smi = [[LCSegmentMergeInfo alloc] initWithBase: [[starts objectAtIndex: i] intValue] termEnumerator: termEnum reader: reader];
		if ((t == nil ? [smi hasNextTerm] : ([termEnum term] != nil)))
			[queue put: smi];          // initialize queue
		else
			[smi close];
		RELEASE(smi);
    }
	
    if (t != nil && [queue size] > 0) {
		[self hasNextTerm];
    }
	return self;
}

- (void) dealloc
{
	DESTROY(queue);
	DESTROY(term);
	[super dealloc];
}

- (BOOL) hasNextTerm
{
	LCSegmentMergeInfo *top = (LCSegmentMergeInfo *)[queue top];
	if (top == nil) {
		term = nil;
		return NO;
    }
	
	/* LuceneKit: Keep a copy so that it won't change along with queue */
	term = [[top term] copy];
	docFreq = 0;
	
	while (top != nil && [term compare: [top term]] == NSOrderedSame) {
		[queue pop];
		docFreq += [[top termEnumerator] documentFrequency];    // increment freq
		if ([top hasNextTerm])
			[queue put: top];          // restore queue
		else
			[top close];          // done with a segment
		top = (LCSegmentMergeInfo *)[queue top];
    }
    return YES;
}

- (LCTerm *) term
{
    return term;
}

- (long) documentFrequency
{
    return docFreq;
}

- (void) close
{
    [queue close];
}

@end

@interface LCMultiTermDocuments (LCPrivate)
- (id <LCTermDocuments>) termDocuments: (int) i;
@end

@implementation LCMultiTermDocuments

- (id) init
{
	self = [super init];
	base = 0;
	pointer = 0;
	return self;
}

- (id) initWithReaders: (NSArray *) r 
                starts: (NSArray *) s
{
	self = [self init];
	ASSIGN(readers, r);
	ASSIGN(starts, s);
	readerTermDocs = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc
{
	RELEASE(readers);
	RELEASE(starts);
	RELEASE(readerTermDocs);
	RELEASE(current);
	[super dealloc];
}

- (long) document
{
	return base + [current document];
}

- (long) frequency
{
	return [current frequency];
}

- (void) seekTerm: (LCTerm *) t
{
	ASSIGN(term, t);
	base = 0;
	pointer = 0;
	DESTROY(current);
}

- (void) seekTermEnumerator: (LCTermEnumerator *) termEnum
{
	[self seekTerm: [termEnum term]];
}

- (BOOL) hasNextDocument
{
    if (current != nil && [current hasNextDocument]) {
		return YES;
    } else if (pointer < [readers count]) {
		base = [[starts objectAtIndex: pointer] intValue];
		ASSIGN(current, [self termDocuments: pointer++]);
		return [self hasNextDocument];
    } else {
		return NO;
    }
}

/** Optimized implementation. */
- (int) readDocuments: (NSMutableArray *) docs frequency: (NSMutableArray *) freqs size: (int) size
{
    while (YES) {
		while (current == nil) {
			if (pointer < [readers count]) {      // try next segment
				base = [[starts objectAtIndex: pointer] intValue];
				ASSIGN(current, [self termDocuments: pointer++]);
			} else {
				return 0;
			}
		}
		int end = [current readDocuments: docs frequency: freqs size: size];
		if (end == 0) {          // none left in segment
			DESTROY(current);
		} else {            // got some
			int b = base;        // adjust doc numbers
			int i;
			for (i = 0; i < end; i++)
			{
				int tmp = [[docs objectAtIndex: i] intValue] + b;;
				[docs replaceObjectAtIndex: i withObject: [NSNumber numberWithInt: tmp]];
			}
        		return end;
		}
    }
}

/** As yet unoptimized implementation. */
- (BOOL) skipTo: (int) target
{
    do {
		if (![self hasNextDocument])
			return NO;
    } while (target > [self document]);
	return YES;
}

- (id <LCTermDocuments>) termDocuments: (int) i
{
    if (term == nil) return nil;
    /* LuceneKit implementation */
    id <LCTermDocuments> result = nil;
    if (i >= [readerTermDocs count]) // Not Exist
    {
		result = [self termDocumentsWithReader: [readers objectAtIndex: i]];
		[readerTermDocs addObject: result];
    }
    [result seekTerm: term];
    return result;
}

- (id <LCTermDocuments>) termDocumentsWithReader: (LCIndexReader *) reader
{
    return [reader termDocuments];
}

- (void) close
{
	int i;
    for (i = 0; i < [readerTermDocs count]; i++) {
		if ([readerTermDocs objectAtIndex: i] != nil)
			[[readerTermDocs objectAtIndex: i] close];
    }
}

@end

@implementation LCMultiTermPositions

- (id <LCTermDocuments>) termDocumentsWithReader: (LCIndexReader *) reader
{
	return (id <LCTermDocuments>)[reader termPositions];
}

- (int) nextPosition
{
	return [(id <LCTermPositions>)current nextPosition];
}

- (NSComparisonResult) compare: (id) o
{
	LCMultiTermPositions *other = (LCMultiTermPositions *) o;
	if ([self document] < [other document])
		return NSOrderedAscending;
	else if ([self document] == [other document])
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

@end
