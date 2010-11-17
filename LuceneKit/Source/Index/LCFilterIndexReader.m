#include "LCFilterIndexReader.h"
#include "LCDocument.h"
#include "GNUstep.h"

@implementation LCFilterTermDocuments

// FIXME: Should implementation getVersion and isCurrent (see latest version)

/** Base class for filtering {@link TermDocs} implementations. */
- (id) initWithTermDocuments: (id <LCTermDocuments>) docs
{
	self = [self init];
	ASSIGN(input, docs);
	return self;
}

- (void) dealloc
{
	DESTROY(input);
	[super dealloc];
}

- (void) seekTerm: (LCTerm *) term
{
	[input seekTerm: term];
}

- (void) seekTermEnumerator: (LCTermEnumerator *) termEnum
{
	[input seekTermEnumerator: termEnum];
}

- (long) document
{
	return [input document];
}

- (long) frequency
{
	return [input frequency];
}

- (BOOL) hasNextDocument
{
	return [input hasNextDocument];
}

- (int) readDocuments: (NSMutableArray *) docs frequency: (NSMutableArray *) freqs size: (int) size
{
	return [input readDocuments: docs frequency: freqs size: size];
}

- (BOOL) skipTo: (int) i
{
	return [input skipTo: i];
}

- (void) close
{
	[input close];
}

@end

/** Base class for filtering {@link TermPositions} implementations. */
@implementation LCFilterTermPositions

- (id) initWithTermPositions: (id <LCTermPositions>) po
{
	return [self initWithTermDocuments: po];
}

- (int) nextPosition
{
	return [(id <LCTermPositions>)input nextPosition];
}

- (NSComparisonResult) compare: (id) o
{
	LCFilterTermPositions *other = (LCFilterTermPositions *) o;
	if ([self document] < [other document])
		return NSOrderedAscending;
	else if ([self document] == [other document])
		return NSOrderedSame;
	else
		return NSOrderedDescending;
}

@end

@implementation LCFilterTermEnumerator

/** Base class for filtering {@link TermEnum} implementations. */
- (id) initWithTermEnumerator: (LCTermEnumerator *) termEnum
{
	self = [self init];
	ASSIGN(input, termEnum);
	return self;
}

- (void) dealloc
{
	DESTROY(input);
	[super dealloc];
}

- (BOOL) hasNextTerm
{
	return [input hasNextTerm];
}

- (LCTerm *) term
{
	return [input term];
}

- (long) documentFrequency
{
	return [input documentFrequency];
}

- (void) close
{
	[input close];
}

@end

@implementation LCFilterIndexReader

/**
* <p>Construct a FilterIndexReader based on the specified base reader.
 * Directory locking for delete, undeleteAll, and setNorm operations is
 * left to the base reader.</p>
 * <p>Note that base reader is closed if this FilterIndexReader is closed.</p>
 * @param in specified base reader.
 */
- (id) initWithIndexReader: (LCIndexReader *) reader
{
	self = [self initWithDirectory: [reader directory]];
	ASSIGN(input, reader);
	return self;
}

- (void) dealloc
{
	DESTROY(input);
	[super dealloc];
}

- (NSArray *) termFrequencyVectors: (int) docNumber
{
	return [input termFrequencyVectors: docNumber];
}

- (id <LCTermFrequencyVector>) termFrequencyVector: (int) docNumber field: (NSString *) field
{
	return [input termFrequencyVector: docNumber field: field];
}

- (int) numberOfDocuments
{
	return [input numberOfDocuments];
}

- (int) maximalDocument
{
	return [input maximalDocument];
}

- (LCDocument *) document: (int) n
{
	return [input document: n];
}

- (BOOL) isDeleted: (int) n
{
	return [input isDeleted: n];
}

- (BOOL) hasDeletions
{
	return [input hasDeletions];
}

- (void) doUndeleteAll
{
	[input undeleteAll];
}

- (BOOL) hasNorms: (NSString *) f
{
	return [input hasNorms: f];
}

- (NSData *) norms: (NSString *) f
{
	return [input norms: f];
}

- (void) setNorms: (NSString *) f bytes: (NSMutableData *) bytes
		   offset: (int) offset
{
	[input setNorms: f bytes: bytes offset: offset];
	
}

- (void) doSetNorm: (int) d field: (NSString *) f
		 charValue: (char) b
{
	[input setNorm: d field: f charValue: b];
}

- (LCTermEnumerator *) termEnumerator
{
	return [input termEnumerator];
}

- (LCTermEnumerator *) termEnumeratorWithTerm: (LCTerm *) t
{
	return [input termEnumeratorWithTerm: t];
}

- (long) documentFrequency: (LCTerm *) t
{
	return [input documentFrequency: t];
}

- (id <LCTermDocuments>) termDocuments
{
	return [input termDocuments];
}

- (id <LCTermPositions>) termPositions
{
	return [input termPositions];
}

- (void) doDelete: (int) n
{
	[input deleteDocument: n];
}

- (void) doCommit
{
	[input commit];
}

- (void) doClose
{
	[input close];
}

- (NSArray *) fieldNames: (LCFieldOption) option
{
	return [input fieldNames: option];
}

@end
