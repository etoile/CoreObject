#include "LCSegmentMerger.h"
#include "LCSegmentMergeInfo.h"
#include "LCSegmentMergeQueue.h"
#include "LCFieldInfos.h"
#include "LCFieldInfo.h"
#include "LCFieldsWriter.h"
#include "LCTermInfosWriter.h"
#include "LCTermInfo.h"
#include "LCTerm.h"
#include "LCTermVectorsWriter.h"
#include "LCIndexReader.h"
#include "LCIndexWriter.h"
#include "LCCompoundFileWriter.h"
#include "LCField.h"
#include "LCIndexOutput.h"
#include "LCRAMOutputStream.h"
#include "GNUstep.h"

/**
* The SegmentMerger class combines two or more Segments, represented by an IndexReader ({@link #add}),
 * into a single Segment.  After adding the appropriate readers, call the merge method to combine the 
 * segments.
 *<P> 
 * If the compoundFile flag is set, then the segments will be merged into a compound file.
 *   
 * 
 * @see #merge
 * @see #add
 */
@interface LCSegmentMerger (LCPrivate)
- (int) mergeFields;
- (void) mergeVectors;

- (void) mergeTerms;
- (void) mergeTermInfos;
- (void) mergeTermInfo: (NSArray *) smis size: (int) n;
- (int) appendPosting: (NSArray *) smis size: (int) n;

- (void) resetSkip;
- (void) bufferSkip: (int) doc;
- (long) writeSkip;
- (void) mergeNorms;

- (void) addIndexed: (LCIndexReader *) r
	  fieldInfos: (LCFieldInfos *) fi
	  names: (NSArray *) n
	 isTermVectorStored: (BOOL) tv
	isStorePositionsWithTermVector: (BOOL) pos
	isStoreOffsetWithTermVector: (BOOL) off;
@end

@implementation LCSegmentMerger

- (id) init
{
	self = [super init];
	termIndexInterval = DEFAULT_TERM_INDEX_INTERVAL;
	readers = [[NSMutableArray alloc] init];
	
	// File extensions of old-style index files
	COMPOUND_EXTENSIONS = [[NSArray alloc] initWithObjects: 
		@"fnm", @"frq", @"prx", @"fdx", @"fdt", @"tii", @"tis", nil];
	VECTOR_EXTENSIONS = [[NSArray alloc] initWithObjects:
		@"tvx", @"tvd", @"tvf", nil];
	
	skipBuffer = [[LCRAMOutputStream alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(directory);
	DESTROY(segment);
	DESTROY(readers);
	DESTROY(fieldInfos);
	DESTROY(COMPOUND_EXTENSIONS);
	DESTROY(VECTOR_EXTENSIONS);

	DESTROY(freqOutput);
	DESTROY(proxOutput);
	DESTROY(termInfosWriter);
	DESTROY(queue);
	DESTROY(skipBuffer);

	[super dealloc];
}

/** This ctor used only by test code.
* 
* @param dir The Directory to merge the other segments into
* @param name The name of the new segment
*/
- (id) initWithDirectory: (id <LCDirectory>) dir name: (NSString *) name
{
	self = [self init];
	ASSIGN(directory, dir);
	ASSIGN(segment, name);
	return self;
}

- (id) initWithIndexWriter: (LCIndexWriter *) writer name: (NSString *) name
{
	self = [self initWithDirectory: [writer directory] name: name];
	termIndexInterval = [writer termIndexInterval];
	return self;
}

/**
* Add an IndexReader to the collection of readers that are to be merged
 * @param reader
 */
- (void) addIndexReader: (LCIndexReader *) reader
{
	[readers addObject: reader];
}

/**
* 
 * @param i The index of the reader to return
 * @return The ith reader to be merged
 */
- (LCIndexReader *) segmentReader: (int) i
{
    return (LCIndexReader *) [readers objectAtIndex: i];
}

/**
* Merges the readers specified by the {@link #add} method into the directory passed to the constructor
 * @return The number of documents that were merged
 * @throws IOException
 */
- (int) merge
{
	int value;
	
	value = [self mergeFields];
	[self mergeTerms];
	[self mergeNorms];
	
	if ([fieldInfos hasVectors])
	{
		[self mergeVectors];
    }
    return value;
}

/**
* close all IndexReaders that have been added.
 * Should not be called before merge().
 * @throws IOException
 */
- (void) closeReaders
{
	int i;
    for (i = 0; i < [readers count]; i++) {  // close readers
		LCIndexReader *reader = (LCIndexReader *) [readers objectAtIndex: i];
		[reader close];
    }
}

- (NSArray *) createCompoundFile: (NSString *) fileName
{
	LCCompoundFileWriter *cfsWriter = [[LCCompoundFileWriter alloc] initWithDirectory: directory name: fileName];
	
	NSMutableArray *files = [[NSMutableArray alloc] init];
    
    // Basic files
    NSString *file;
    int i;
    for (i = 0; i < [COMPOUND_EXTENSIONS count]; i++) {
		file = [segment stringByAppendingPathExtension: [COMPOUND_EXTENSIONS objectAtIndex: i]];
		[files addObject: file];
    }
	
    // Field norm files
    for (i = 0; i < [fieldInfos size]; i++) {
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: i];
		if ([fi isIndexed] && (![fi omitNorms])) {
			file = [segment stringByAppendingPathExtension: [NSString stringWithFormat: @"f%d", i]];
			[files addObject: file];
		}
    }
	
    // Vector files
    if ([fieldInfos hasVectors]) {
		for (i = 0; i < [VECTOR_EXTENSIONS count]; i++) {
			file = [segment stringByAppendingPathExtension: [VECTOR_EXTENSIONS objectAtIndex: i]];
			[files addObject: file];
		}
    }
	
    // Now merge all added files
    NSEnumerator *e = [files objectEnumerator];
    while ((file = [e nextObject])) {
		[cfsWriter addFile: file];
    }
    
    // Perform the merge
    [cfsWriter close];
    DESTROY(cfsWriter);
	
    return AUTORELEASE(files);
}

- (void) addIndexed: (LCIndexReader *) r
          fieldInfos: (LCFieldInfos *) fi
          names: (NSArray *) n
         isTermVectorStored: (BOOL) tv
        isStorePositionWithTermVector: (BOOL) pos
        isStoreOffsetWithTermVector: (BOOL) off
{
	NSEnumerator *e = [n objectEnumerator];
	NSString *field;
	while ((field = [e nextObject]))
	{
		[fi addName: field
           isIndexed: YES
         isTermVectorStored: tv
         isStorePositionWithTermVector: pos
         isStoreOffsetWithTermVector: off
        omitNorms: (![r hasNorms: field])];
	}
}

/**
* 
 * @return The number of documents in all of the readers
 * @throws IOException
 */
- (int) mergeFields
{
	ASSIGN(fieldInfos, AUTORELEASE([[LCFieldInfos alloc] init]));  // merge field names
	//fieldInfos = [[LCFieldInfos alloc] init];  // merge field names
	int docCount = 0;
	int i;
	LCIndexReader *reader;
	for (i = 0; i < [readers count]; i++) {
		reader = (LCIndexReader *) [readers objectAtIndex: i];
  [self addIndexed: reader
                fieldInfos: fieldInfos
                names: [reader fieldNames: LCFieldOption_TERMVECTOR_WITH_POSITION_OFFSET]
                isTermVectorStored: YES
                isStorePositionWithTermVector: YES
                isStoreOffsetWithTermVector: YES];
  [self addIndexed: reader
                fieldInfos: fieldInfos
                names: [reader fieldNames: LCFieldOption_TERMVECTOR_WITH_POSITION]
                isTermVectorStored: YES
                isStorePositionWithTermVector: YES
                isStoreOffsetWithTermVector: NO];
  [self addIndexed: reader
                fieldInfos: fieldInfos
                names: [reader fieldNames: LCFieldOption_TERMVECTOR_WITH_OFFSET]
                isTermVectorStored: YES
                isStorePositionWithTermVector: NO 
                isStoreOffsetWithTermVector: YES];
  [self addIndexed: reader
                fieldInfos: fieldInfos
                names: [reader fieldNames: LCFieldOption_TERMVECTOR]
                isTermVectorStored: YES
                isStorePositionWithTermVector: NO
                isStoreOffsetWithTermVector: NO];
  [self addIndexed: reader
                fieldInfos: fieldInfos
                names: [reader fieldNames: LCFieldOption_INDEXED]
		isTermVectorStored: NO
                isStorePositionWithTermVector: NO
                isStoreOffsetWithTermVector: NO];
  [fieldInfos addCollection: [reader fieldNames: LCFieldOption_UNINDEXED]
                                                isIndexed: NO];
    }
    NSString *file = [segment stringByAppendingPathExtension: @"fnm"];
    [fieldInfos write: directory name: file];
	
    LCFieldsWriter *fieldsWriter = // merge field values
		[[LCFieldsWriter alloc] initWithDirectory: directory
										  segment: segment
									   fieldInfos: fieldInfos];
	
    for (i = 0; i < [readers count]; i++) {
		
		LCIndexReader *reader = (LCIndexReader *) [readers objectAtIndex: i];
		int maxDoc = [reader maximalDocument];
		int j;
		for (j = 0; j < maxDoc; j++)
			if (![reader isDeleted: j]) {               // skip deleted docs
				[fieldsWriter addDocument: [reader document: j]];
				docCount++;
			}
	}
		[fieldsWriter close];
		DESTROY(fieldsWriter);
		return docCount;
}

/**
* Merge the TermVectors from each of the segments into the new one.
 * @throws IOException
 */
- (void) mergeVectors
{
	LCTermVectorsWriter *termVectorsWriter = 
    [[LCTermVectorsWriter alloc] initWithDirectory: directory segment: segment fieldInfos: fieldInfos];
	
	int r;
	for (r = 0; r < [readers count]; r++) {
		LCIndexReader *reader = (LCIndexReader *) [readers objectAtIndex: r];
		int maxDoc = [reader maximalDocument];
		int docNum;
		for (docNum = 0; docNum < maxDoc; docNum++) {
			// skip deleted docs
			if ([reader isDeleted: docNum]) 
				continue;
			[termVectorsWriter addAllDocumentVectors: [reader termFrequencyVectors: docNum]];
		}
	}
	[termVectorsWriter close];
	DESTROY(termVectorsWriter);
}

- (void) mergeTerms;
{
	NSString *file = [segment stringByAppendingPathExtension: @"frq"];
	ASSIGN(freqOutput, [directory createOutput: file]);
	file = [segment stringByAppendingPathExtension: @"prx"];
	ASSIGN(proxOutput, [directory createOutput: file]);
	ASSIGN(termInfosWriter, AUTORELEASE([[LCTermInfosWriter alloc] initWithDirectory: directory
														   segment: segment
														fieldInfos: fieldInfos
														  interval: termIndexInterval]));
	skipInterval = [termInfosWriter skipInterval];
	ASSIGN(queue, AUTORELEASE([(LCSegmentMergeQueue *)[LCSegmentMergeQueue alloc] initWithSize: [readers count]]));
	
	[self mergeTermInfos];
	
	if (freqOutput != nil) [freqOutput close];
	if (proxOutput != nil) [proxOutput close];
	if (termInfosWriter != nil) [termInfosWriter close];
	if (queue != nil) [queue close];
}

- (void) mergeTermInfos
{
	int base = 0;
	int i;
	for (i = 0; i < [readers count]; i++) {
		LCIndexReader *reader = (LCIndexReader *) [readers objectAtIndex: i];
		LCTermEnumerator *termEnum = [reader termEnumerator];
		LCSegmentMergeInfo *smi = [[LCSegmentMergeInfo alloc] initWithBase: base
																  termEnumerator: termEnum reader: reader];
		base += [reader numberOfDocuments];
		if ([smi hasNextTerm])
		{
			[queue put: smi];				  // initialize queue
		}
		else
			[smi close];
		DESTROY(smi);
    }
	
    NSMutableArray *match = [[NSMutableArray alloc] init];
	
    while ([queue size] > 0) {
		int matchSize = 0;			  // pop matching terms
		if (matchSize < [match count])
			[match replaceObjectAtIndex: matchSize withObject: [queue pop]];
		else
			[match addObject: [queue pop]];
		
		matchSize++;
		LCTerm *term = [[match objectAtIndex: 0] term];
		LCSegmentMergeInfo *top = (LCSegmentMergeInfo *) [queue top];
		
		while (top != nil && [term compare: [top term]] == NSOrderedSame) {
			if (matchSize < [match count])
				[match replaceObjectAtIndex: matchSize withObject: [queue pop]];
			else
				[match addObject: [queue pop]];
			matchSize++;
			top = (LCSegmentMergeInfo *) [queue top];
		}
		
		[self mergeTermInfo: match size: matchSize]; // add new TermInfo
		
		while (matchSize > 0) {
			LCSegmentMergeInfo *smi = [match objectAtIndex: --matchSize];
			if ([smi hasNextTerm])
				[queue put: smi];			  // restore queue
			else
				[smi close];				  // done with a segment
		}
    }
	DESTROY(match);
}

/** Merge one term found in one or more segments. The array <code>smis</code>
*  contains segments that are positioned at the same term. <code>N</code>
*  is the number of cells in the array actually occupied.
*
* @param smis array of segments
* @param n number of cells in the array actually occupied
*/
- (void) mergeTermInfo: (NSArray *) smis size: (int) n
{
	long freqPointer = [freqOutput offsetInFile];
	long proxPointer = [proxOutput offsetInFile];
	
	int df = [self appendPosting: smis size: n];		  // append posting data
	
	long skipPointer = [self writeSkip];

	
	if (df > 0) {
		LCTermInfo *ti = [[LCTermInfo alloc] init];
		// add an entry to the dictionary with pointers to prox and freq files
		[ti setDocumentFrequency: df];
		[ti setFreqPointer: freqPointer];
		[ti setProxPointer: proxPointer];
		[ti setSkipOffset: (long)(skipPointer - freqPointer)];
		[termInfosWriter addTerm: [[smis objectAtIndex: 0] term]
						termInfo: ti];
		DESTROY(ti);
    }
}

/** Process postings from multiple segments all positioned on the
*  same term. Writes out merged entries into freqOutput and
*  the proxOutput streams.
*
* @param smis array of segments
* @param n number of cells in the array actually occupied
* @return number of documents across all segments where this term was found
*/
- (int) appendPosting: (NSArray *) smis size: (int) n
{
    int lastDoc = 0;
    int df = 0;					  // number of docs w/ term
    [self resetSkip];
    int i;
    for (i = 0; i < n; i++) {
		LCSegmentMergeInfo *smi = [smis objectAtIndex: i];
		id <LCTermPositions> postings = [smi postings];
		int base = [smi base];
		NSArray *docMap = [smi docMap];
		[postings seekTermEnumerator: [smi termEnumerator]];
		while ([postings hasNextDocument]) {
			int doc = [postings document];
			if (docMap != nil)
				doc = [[docMap objectAtIndex: doc] intValue]; // map around deletions
			doc += base;                              // convert to merged space
			
			if (doc < lastDoc)
			{
				NSLog(@"docs out of order");
			}
			
			df++;
			
			if ((df % skipInterval) == 0) {
				[self bufferSkip: lastDoc];
			}
			
			int docCode = (doc - lastDoc) << 1;	  // use low bit to flag freq=1
			lastDoc = doc;
			
			int freq = [postings frequency];
			if (freq == 1) {
				[freqOutput writeVInt: (docCode | 1)];  // write doc & freq=1
			} else {
				[freqOutput writeVInt: docCode];	  // write doc
				[freqOutput writeVInt: freq];		  // write frequency in doc
			}
			
			int lastPosition = 0;			  // write position deltas
			int j;
			for (j = 0; j < freq; j++) {
				int position = [postings nextPosition];
				[proxOutput writeVInt: position - lastPosition];
				lastPosition = position;
			}
		}
    }
    return df;
}

- (void) resetSkip
{
    [skipBuffer reset];
    lastSkipDoc = 0;
    lastSkipFreqPointer = [freqOutput offsetInFile];
    lastSkipProxPointer = [proxOutput offsetInFile];
}

- (void) bufferSkip: (int) doc
{
    long freqPointer = [freqOutput offsetInFile];
    long proxPointer = [proxOutput offsetInFile];
	
    [skipBuffer writeVInt: (doc - lastSkipDoc)];
    [skipBuffer writeVInt: ((int) (freqPointer - lastSkipFreqPointer))];
    [skipBuffer writeVInt: ((int) (proxPointer - lastSkipProxPointer))];
	
    lastSkipDoc = doc;
    lastSkipFreqPointer = freqPointer;
    lastSkipProxPointer = proxPointer;
}

- (long) writeSkip
{
    long skipPointer = [freqOutput offsetInFile];
    [skipBuffer writeTo: freqOutput];
    return skipPointer;
}

- (void) mergeNorms
{
	int i;
    for (i = 0; i < [fieldInfos size]; i++) {
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: i];
		if ([fi isIndexed] && (![fi omitNorms])) {
			NSString *file = [segment stringByAppendingPathExtension: [NSString stringWithFormat: @"f%d", i]];
			LCIndexOutput *output = [directory createOutput: file];
			int j;
			for (j = 0; j < [readers count]; j++) {
				LCIndexReader *reader = (LCIndexReader *) [readers objectAtIndex: j];

				NSMutableData *input = [[NSMutableData alloc] init];
				[reader setNorms: [fi name] bytes: input offset: 0];
				int k;
				char *bytes = (char *)[input bytes];
				int maxDoc = [input length];
				for (k = 0; k < maxDoc; k++) {
					if (![reader isDeleted: k]) {
						[output writeByte: bytes[k]];
					}
				}
				DESTROY(input);
			}
			[output close];
		}
    }
}

@end
