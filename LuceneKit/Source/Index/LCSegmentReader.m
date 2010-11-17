#include "LCSegmentReader.h"
#include "LCSegmentTermPositions.h"
#include "LCDocument.h"
#include "LCIndexInput.h"
#include "LCIndexOutput.h"
#include "LCDirectory.h"
#include "LCFieldsReader.h"
#include "LCTermVectorsReader.h"
#include "LCTermInfo.h"
#include "LCDefaultSimilarity.h"
#include "GNUstep.h"

@interface LCNorm: NSObject
{
	LCSegmentReader *reader;
	LCIndexInput *input;
	NSMutableData *bytes;
	BOOL dirty;
	int number;
}

- (id) initWithSegmentReader: (LCSegmentReader *) r
				  indexInput: (LCIndexInput *) input number: (int) number;
- (void) rewrite;
- (LCIndexInput *) input;
- (BOOL) dirty;
- (void) setDirty: (BOOL) d;
- (NSData *) bytes;
- (void) setBytes: (NSData *) bytes;
@end


@implementation LCNorm

- (id) initWithSegmentReader: (LCSegmentReader *) r
                  indexInput: (LCIndexInput *) inp number: (int) num
{
	self = [self init];
	reader = r; //Don't assign as reader retain us
	ASSIGN(input, inp);
	bytes = [[NSMutableData alloc] init];
	number = num;
	return self;
}

- (void) dealloc
{
	//Don't destroy reader as we not retain it
	DESTROY(input);
	DESTROY(bytes);
	[super dealloc];
}

- (void) rewrite
{
	// NOTE: norms are re-written in regular directory, not cfs
	LCIndexOutput *out = [[reader directory] createOutput: [[reader segment] stringByAppendingPathExtension: @"tmp"]];
	[out writeBytes: bytes length: [reader maximalDocument]];
	[out close];
	
	NSString *fileName;
	if([reader cfsReader] == nil)
		fileName = [NSString stringWithFormat: @"%@.f%d", [reader segment], number];
	else{ 
		// use a different file name if we have compound format
        fileName = [NSString stringWithFormat: @"%@.s%d", [reader segment], number];
	}
	[[reader directory] renameFile: [[reader segment] stringByAppendingPathExtension: @"tmp"]
								to: fileName];
	dirty = NO;
}

- (BOOL) dirty
{
	return dirty;
}

- (void) setDirty: (BOOL) b
{
	dirty = b;
}

- (NSData *) bytes
{
	return bytes;
}

- (void) setBytes: (NSData *) b
{
	[bytes setData: b];
}

- (LCIndexInput *) input
{
	return input;
}

@end

@interface LCSegmentReader (LCPrivate)
- (void) initWithSegmentInfo: (LCSegmentInfo *) si;
- (void) openNorms: (id <LCDirectory>) cfsDir;
- (void) closeNorms;
- (LCTermVectorsReader *) termVectorsReader;

@end

@implementation LCSegmentReader: LCIndexReader

- (id) init
{
	self = [super init];
	deletedDocsDirty = NO;
	normsDirty = NO;
	undeleteAll = NO;
	ASSIGN(norms, AUTORELEASE([[NSMutableDictionary alloc] init]));
	termVectorsReaderOrig = nil;
	return self;
}

+ (id) segmentReaderWithInfo: (LCSegmentInfo *) si
{
	return [LCSegmentReader segmentReaderWithDirectory: [si directory]
												  info: si
												 infos: nil
												 close: NO
												 owner: NO];
}

+ (id) segmentReaderWithInfos: (LCSegmentInfos *) sis
                         info: (LCSegmentInfo *) si
                        close: (BOOL) closeDir
{
	return [LCSegmentReader segmentReaderWithDirectory: [si directory]
												  info: si
												 infos: sis
												 close: closeDir
												 owner: YES];
}

+ (id) segmentReaderWithDirectory: (id <LCDirectory>) dir
							 info: (LCSegmentInfo *) si
                            infos: (LCSegmentInfos *) sis
                            close: (BOOL) closeDir
                            owner: (BOOL) ownDir
{
	LCSegmentReader *instance = [[LCSegmentReader alloc] initWithDirectory: dir
															  segmentInfos: sis
															closeDirectory: closeDir
															directoryOwner: ownDir];
	[instance initWithSegmentInfo: si];
	return AUTORELEASE(instance);
}

- (void) initWithSegmentInfo: (LCSegmentInfo *) si
{
	ASSIGN(segment, [si name]);
	if ((segment == nil) && ([segment length] == 0))
		NSLog(@"Error: nil segment");
	// Use compound file directory for some files, if it exists
	id <LCDirectory> cfsDir = nil;
	ASSIGN(cfsDir, [self directory]);
	NSString *file = [segment stringByAppendingPathExtension: @"cfs"];
	if ([directory fileExists: file]) {
		ASSIGN(cfsReader, AUTORELEASE([[LCCompoundFileReader alloc] initWithDirectory: [self directory] name: file]));
		ASSIGN(cfsDir, cfsReader);
	}
	
	// No compound file exists - use the multi-file format
	file = [segment stringByAppendingPathExtension: @"fnm"];
	ASSIGN(fieldInfos, AUTORELEASE([[LCFieldInfos alloc] initWithDirectory: cfsDir name: file]));
	ASSIGN(fieldsReader, AUTORELEASE([[LCFieldsReader alloc] initWithDirectory: cfsDir
																	   segment: segment
																	fieldInfos: fieldInfos]));
	
	ASSIGN(tis, AUTORELEASE([[LCTermInfosReader alloc] initWithDirectory: cfsDir
																 segment: segment
															  fieldInfos: fieldInfos]));
	
	// NOTE: the bitvector is stored using the regular directory, not cfs
	if ([LCSegmentReader hasDeletions: si])
    {
		file = [segment stringByAppendingPathExtension: @"del"];
		ASSIGN(deletedDocs, AUTORELEASE([[LCBitVector alloc] initWithDirectory: [self directory]
																	   name: file]));
    }
	
	// make sure that all index files have been read or are kept open
	// so that if an index update removes them we'll still have them
	file = [segment stringByAppendingPathExtension: @"frq"];
	ASSIGN(freqStream, [cfsDir openInput: file]);
	file = [segment stringByAppendingPathExtension: @"prx"];
	ASSIGN(proxStream, [cfsDir openInput: file]);
	[self openNorms: cfsDir];
	
	if ([fieldInfos hasVectors]) { // open term vector files only as needed
		ASSIGN(termVectorsReaderOrig, AUTORELEASE([[LCTermVectorsReader alloc] initWithDirectory: cfsDir segment: segment fieldInfos: fieldInfos]));
	}
	DESTROY(cfsDir);
}

- (void) dealloc
{
	DESTROY(norms);
	DESTROY(segment);
	DESTROY(fieldInfos);
	DESTROY(fieldsReader);
	DESTROY(tis);
	DESTROY(termVectorsReaderOrig);
	DESTROY(deletedDocs);
	DESTROY(freqStream);
	DESTROY(proxStream);
	DESTROY(cfsReader);
	[super dealloc];
}

- (void) doCommit
{
	CREATE_AUTORELEASE_POOL(pool);
	NSString *file;
	if (deletedDocsDirty) {               // re-write deleted 
		file = [segment stringByAppendingPathExtension: @"tmp"];
		[deletedDocs writeToDirectory: [self directory]
							 name: file];
		[[self directory] renameFile: file
								  to: [segment stringByAppendingPathExtension: @"del"]];
	}
	
	file = [segment stringByAppendingPathExtension: @"del"];
	if (undeleteAll && [[self directory] fileExists:  file]){
		[[self directory] deleteFile: file];
	}
	if (normsDirty) {               // re-write norms 
		NSEnumerator *values = [norms objectEnumerator];
		LCNorm *norm;
		while ((norm = [values nextObject])) {
			if ([norm dirty]) {
				[norm rewrite];
			}
		}
	}
	
	deletedDocsDirty = NO;
	normsDirty = NO;
	undeleteAll = NO;
	DESTROY(pool);
}

- (void) doClose
{
	[fieldsReader close];
	[tis close];
	
	if (freqStream != nil)
		[freqStream close];
	if (proxStream != nil)
		[proxStream close];
	
	[self closeNorms];
    
	if (termVectorsReaderOrig != nil) 
		[termVectorsReaderOrig close];
	
	if (cfsReader != nil)
		[cfsReader close];
}

+ (BOOL) hasDeletions: (LCSegmentInfo *) si
{
	return [[si directory] fileExists: [[si name] stringByAppendingPathExtension: @"del"]];
}

- (BOOL) hasDeletions
{
	return deletedDocs != nil;
}

+ (BOOL) usesCompoundFile: (LCSegmentInfo *) si
{
	return [[si directory] fileExists: [[si name] stringByAppendingPathExtension: @"cfs"]];
}

+ (BOOL) hasSeparateNorms: (LCSegmentInfo *) si
{
	NSArray *result = [[si directory] fileList];
	NSString *pattern = [[si name] stringByAppendingPathExtension: @"s"];
	int patternLength = [pattern length];
	int i;
	for(i = 0; i < [result count]; i++){
		unichar ch = [[result objectAtIndex: i] characterAtIndex: patternLength];
		if (([[result objectAtIndex: i] hasPrefix: pattern]) &&
		    ((ch >= '0') && (ch <= '9') /* isDigit */))
			return YES;
    }
    return NO;
}

- (void) doDelete: (int) docNum
{
	CREATE_AUTORELEASE_POOL(pool);
	if (deletedDocs == nil)
		ASSIGN(deletedDocs, AUTORELEASE([(LCBitVector *)[LCBitVector alloc] initWithSize: [self maximalDocument]]));
	deletedDocsDirty = YES;
	undeleteAll = NO;
	[deletedDocs setBit: docNum];
	DESTROY(pool);
}

- (void) doUndeleteAll
{
	deletedDocs = nil;
	deletedDocsDirty = NO;
	undeleteAll = YES;
}

- (NSArray *) files
{
	NSMutableArray *files = [[NSMutableArray alloc] init];
	NSArray *ext = [NSArray arrayWithObjects: @"cfs", @"fnm",
		@"fdx", @"fdt", @"tii", @"tis", @"frq", @"prx", @"del",
		@"tvx", @"tvd", @"tvf", @"tvp", nil];
	
	int i;
	for (i = 0; i < [ext count]; i++) {
		NSString *name = [NSString stringWithFormat: @"%@.%@", segment, [ext objectAtIndex: i]];
		if ([[self directory] fileExists: name])
			[files addObject: name];
    }
	
    for (i = 0; i < [fieldInfos size]; i++) {
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: i];
		if ([fi isIndexed] && (![fi omitNorms])){
			NSString *name;
			if(cfsReader == nil)
				name = [NSString stringWithFormat: @"%@.f%d", segment, i];
			else
				name = [NSString stringWithFormat: @"%@.s%d", segment, i];
			if ([[self directory] fileExists: name])
				[files addObject: name];
		}
    }
    return AUTORELEASE(files);
}

- (LCTermEnumerator *) termEnumerator
{
    return (LCTermEnumerator *)[tis termEnumerator];
}

- (LCTermEnumerator *) termEnumeratorWithTerm: (LCTerm *) t
{
    return (LCTermEnumerator *)[tis termEnumeratorWithTerm: t];
}

- (LCDocument *) document: (int) n
{
    if ([self isDeleted: n])
    {
		NSLog(@"attempt to access a deleted document");
		return nil;
    }
    return [fieldsReader document: n];
}

- (BOOL) isDeleted: (int) n
{
    return (deletedDocs != nil && [deletedDocs bit: n]);
}

- (id <LCTermDocuments>) termDocuments
{
	return AUTORELEASE([[LCSegmentTermDocuments alloc] initWithSegmentReader: self]);
}

- (id <LCTermPositions>) termPositions
{
	return AUTORELEASE([[LCSegmentTermPositions alloc] initWithSegmentReader: self]);
}

- (long) documentFrequency: (LCTerm *) t
{
    LCTermInfo *ti = [tis termInfo: t];
    if (ti != nil)
    {
		return [ti documentFrequency];
    }
    else
		return 0;
}

- (int) numberOfDocuments
{
    int n = [self maximalDocument];
    if (deletedDocs != nil)
    {
		n -= [deletedDocs count];
    }
    return n;
}

- (int) maximalDocument
{
	if (fieldsReader)
		return [fieldsReader size];
	else
	{
		NSLog(@"No FieldsReader");
		return 0;
    }
}

/**
* @see IndexReader#getFieldNames(IndexReader.FieldOption fldOption)
 */
- (NSArray *) fieldNames: (LCFieldOption) fieldOption
{
	NSMutableArray *fieldSet = [[NSMutableArray alloc] init];
	int i;
	for (i = 0; i < [fieldInfos size]; i++) {
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: i];
		if (fieldOption == LCFieldOption_ALL) {
			[fieldSet addObject: [fi name]];
		}
		else if (![fi isIndexed] && fieldOption == LCFieldOption_UNINDEXED) {
			[fieldSet addObject: [fi name]];
		}
		else if ([fi isIndexed] && fieldOption == LCFieldOption_INDEXED) {
			[fieldSet addObject: [fi name]];
		}
		else if ([fi isIndexed] && [fi isTermVectorStored] == NO && 
				 fieldOption == LCFieldOption_INDEXED_NO_TERMVECTOR) {
			[fieldSet addObject: [fi name]];
		}
		else if ([fi isTermVectorStored] == YES &&
				 [fi isPositionWithTermVectorStored] == NO &&
				 [fi isOffsetWithTermVectorStored] == NO &&
				 fieldOption == LCFieldOption_TERMVECTOR) {
			[fieldSet addObject: [fi name]];
		}
		else if ([fi isIndexed] && [fi isTermVectorStored] && fieldOption == LCFieldOption_INDEXED_WITH_TERMVECTOR) {
			[fieldSet addObject: [fi name]];
		}
		else if ([fi isPositionWithTermVectorStored] && [fi isOffsetWithTermVectorStored] == NO && fieldOption == LCFieldOption_TERMVECTOR_WITH_POSITION) {
			[fieldSet addObject: [fi name]];
		}
		else if ([fi isOffsetWithTermVectorStored] && [fi isPositionWithTermVectorStored] == NO && fieldOption == LCFieldOption_TERMVECTOR_WITH_OFFSET) {
			[fieldSet addObject: [fi name]];
		}
		else if (([fi isOffsetWithTermVectorStored] && [fi isPositionWithTermVectorStored]) &&
				 fieldOption == LCFieldOption_TERMVECTOR_WITH_POSITION_OFFSET) {
			[fieldSet addObject: [fi name]];
		}
    }
    return AUTORELEASE(fieldSet);
}

- (BOOL) hasNorms: (NSString *) field
{
	return ([norms objectForKey: field] != nil);
}

+ (NSData *) createFakeNorms: (int) size
{
        int i;
        char *p = malloc(sizeof(char)*size);
        char b = [LCDefaultSimilarity encodeNorm: 1.0f];
        for (i = 0; i < size; i++)
	{
		*(p+i) = b;
	}
        NSData *d = [NSData dataWithBytes: p length: size];
        free(p);
        return d;
}

- (NSData *) fakeNorms
{
	if (ones == nil) ASSIGN(ones, [LCSegmentReader createFakeNorms: [self maximalDocument]]);
	return ones;
}

- (NSData *) getNorms: (NSString *) field
{
    LCNorm *norm = (LCNorm *) [norms objectForKey: field];
    if (norm == nil)                             // not an indexed field
                return nil;
    if (([norm bytes] == nil) || ([[norm bytes] length] == 0)) {                
     // value not yet read
                NSMutableData *bytes = [[NSMutableData alloc] init];
                [self setNorms: field bytes: bytes offset: 0];
                [norm setBytes: bytes]; // cache it
                DESTROY(bytes);
    }
    return [norm bytes];
}

- (NSData *) norms: (NSString *) field
{
  NSData *d = [self getNorms: field];
  if (d == nil) {
	d = [self fakeNorms];
  }
  return d;
}

- (void) doSetNorm: (int) doc field: (NSString *) field charValue: (char) value
{
	LCNorm *norm = (LCNorm *) [norms objectForKey: field];
    if (norm == nil)                             // not an indexed field
		return;
    [norm setDirty: YES];                            // mark it dirty
    normsDirty = YES;
	
#if 0 
    norms(field)[doc] = value;                    // set the value
#else
	NSMutableData *d = [[NSMutableData alloc] initWithData: [self norms: field]]; 
	NSRange r = NSMakeRange(doc, 1);
	[d replaceBytesInRange: r withBytes: &value length: 1];
    [norm setBytes: d];
	DESTROY(d);
#endif
}

/** Read norms into a pre-allocated array. */
- (void) setNorms: (NSString *) field
            bytes: (NSMutableData *) bytes offset: (int) offset
{
    LCNorm *norm = (LCNorm *) [norms objectForKey: field];
    if (norm == nil)
        {
                NSRange r = NSMakeRange(offset, [self maximalDocument]);
                [bytes replaceBytesInRange: r withBytes: [self fakeNorms]];
                return;                                   // use zeros in array
        }
	
    if (([norm bytes] != nil) && ([[norm bytes] length] > 0)) {                     // can copy from cache
		NSRange r = NSMakeRange(offset, [self maximalDocument]);
		[bytes replaceBytesInRange: r withBytes: [norm bytes]];
		return;
    }
	
    LCIndexInput *normStream = (LCIndexInput *) AUTORELEASE([[norm input] copy]);
	// read from disk
    [normStream seekToFileOffset: 0];
    [normStream readBytes: bytes offset: offset length: [self maximalDocument]];
    [normStream close];
}

- (void) openNorms: (id <LCDirectory>) cfsDir
{
	int i;
	id <LCDirectory> d = nil;
	NSString *fileName = nil;
	for (i = 0; i < [fieldInfos size]; i++) {
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: i];
		if ([fi isIndexed] && (![fi omitNorms])) {
			// look first if there are separate norms in compound f%ormat
			fileName = [NSString stringWithFormat: @"%@.s%d", segment, [fi number]];
			d = [self directory];
			if([d fileExists: fileName] == NO) {
				fileName = [NSString stringWithFormat: @"%@.f%d", segment, [fi number]];
				d = cfsDir;
			}
			[norms setObject: AUTORELEASE([[LCNorm alloc] initWithSegmentReader: self
                                                                      indexInput: [d openInput: fileName] number: [fi number]])
					  forKey: [fi name]];
		}
    }
}

- (void) closeNorms
{
	NSEnumerator *e = [norms objectEnumerator];
	LCNorm *norm;
	while ((norm = [e nextObject])) {
        [[norm input] close];
	}
}

/**
* Create a clone from the initial TermVectorsReader and store it in the ThreadLocal.
 * @return TermVectorsReader
 */
- (LCTermVectorsReader *) termVectorsReader
{
#if 0
	TermVectorsReader tvReader = (TermVectorsReader)termVectorsLocal.get();
	if (tvReader == null) {
		tvReader = (TermVectorsReader)termVectorsReaderOrig.clone();
		termVectorsLocal.set(tvReader);
	}
#else
	// FIXME: Not thread safe
	return termVectorsReaderOrig;
#endif
#if 0
    if (tvReader == nil) {
		tvReader = (LCTermVectorsReader *)[termVectorsReaderOrig copy];
    }
    return tvReader;
#endif
}

/** Return a term frequency vector for the specified document and field. The
*  vector returned contains term numbers and frequencies for all terms in
*  the specified field of this document, if the field had storeTermVector
*  flag set.  If the flag was not set, the method returns null.
* @throws IOException
*/
- (id <LCTermFrequencyVector>) termFrequencyVector: (int) docNumber
								   field: (NSString *) field
{
    // Check if this field is invalid or has no stored term vector
    LCFieldInfo *fi = [fieldInfos fieldInfo: field];
    if (fi == nil|| ![fi isTermVectorStored] || termVectorsReaderOrig == nil) 
		return nil;
    
    LCTermVectorsReader *termVectorsReader = [self termVectorsReader];
    if (termVectorsReader == nil)
		return nil;
    
    return [termVectorsReader termFrequencyVector: docNumber
												   field: field];
}


/** Return an array of term frequency vectors for the specified document.
*  The array contains a vector for each vectorized field in the document.
*  Each vector vector contains term numbers and frequencies for all terms
*  in a given vectorized field.
*  If no such fields existed, the method returns null.
* @throws IOException
*/
- (NSArray *) termFrequencyVectors: (int) docNumber
{
    if (termVectorsReaderOrig == nil)
		return nil;
    
    LCTermVectorsReader *termVectorsReader = [self termVectorsReader];
    if (termVectorsReader == nil)
		return nil;
    
    return [termVectorsReader termFrequencyVectors: docNumber];
}

- (NSString *) segment
{
	return segment;
}

- (LCCompoundFileReader *) cfsReader
{
	return cfsReader;
}

- (LCIndexInput *) freqStream
{
	return freqStream;
}

- (LCIndexInput *) proxStream
{
	return proxStream;
}

- (LCFieldInfos *) fieldInfos
{
	return fieldInfos;
}

- (LCBitVector *) deletedDocs
{
	return deletedDocs;
}

- (LCTermInfosReader *) termInfosReader
{
	return tis;
}

@end
