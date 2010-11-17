#include "LCTermVectorsReader.h"
#include "LCTermVectorsWriter.h"
#include "LCSegmentTermVector.h"
#include "LCSegmentTermPositionVector.h"
#include "LCTermVectorOffsetInfo.h"
#include "GNUstep.h"

@interface LCTermVectorsReader (LCPrivate)
- (long) checkValidFormat: (LCIndexInput *) input;
- (NSArray *) readTermVectors: (NSArray *) fields
					 pointers: (NSArray *) tvfPOinters;
- (LCSegmentTermVector *) readTermVector: (NSString *) field
                                 pointer: (long long) tvfPointer;

@end

@implementation LCTermVectorsReader

- (id) initWithDirectory: (id <LCDirectory>) d
                 segment: (NSString *) segment
              fieldInfos: (LCFieldInfos *) fis
{
	self = [super init];
	NSString *file = [segment stringByAppendingPathExtension: TVX_EXTENSION];
	if ([d fileExists: file])
	{
		ASSIGN(tvx, [d openInput: file]);
		[self checkValidFormat: tvx];
		file = [segment stringByAppendingPathExtension: TVD_EXTENSION];
		ASSIGN(tvd, [d openInput: file]);
		tvdFormat = [self checkValidFormat: tvd];
		file = [segment stringByAppendingPathExtension: TVF_EXTENSION];
		ASSIGN(tvf, [d openInput: file]);
		tvfFormat = [self checkValidFormat: tvf];
		size = (long) [tvx length] / 8;
	}
	
	ASSIGN(fieldInfos, fis);
	return self;
}

- (void) dealloc
{
	RELEASE(tvx);
	RELEASE(tvd);
	RELEASE(tvf);
	DESTROY(fieldInfos);
	[super dealloc];
}

- (long) checkValidFormat: (LCIndexInput *) input
{
    long format = [input readInt];
    if (format > TERM_VECTORS_WRITER_FORMAT_VERSION)
    {
		NSLog(@"Incompatible format version: %ld expected or less", format);
		return -1;
    }
    return format;
}

- (void) close
{
	// make all effort to close up. Keep the first exception
	// and throw it as a new one.
	if (tvx != nil) [tvx close];
	if (tvd != nil) [tvd close];
	if (tvf != nil) [tvf close];
}

/**
* 
 * @return The number of documents in the reader
 */
- (int) size
{
	return size;
}

/**
* Retrieve the term vector for the given document and field
 * @param docNum The document number to retrieve the vector for
 * @param field The field within the document to retrieve
 * @return The TermFreqVector for the document and field or null if there is no termVector for this field.
 * @throws IOException if there is an error reading the term vector files
 */ 
- (id <LCTermFrequencyVector>) termFrequencyVector: (int) docNum
											   field: (NSString *) field
{
    // Check if no term vectors are available for this segment at all
	int fieldNumber = [fieldInfos fieldNumber: field];
	id <LCTermFrequencyVector> result = nil;
	if (tvx != nil) {
		//We need to account for the FORMAT_SIZE at when seeking in the tvx
		//We don't need to do this in other seeks because we already have the
		// file pointer
		//that was written in another file
		[tvx seekToFileOffset: ((docNum * 8L) + TERM_VECTORS_WRITER_FORMAT_SIZE)];
		long long position = [tvx readLong];
		
		[tvd seekToFileOffset: position];
		long fieldCount = [tvd readVInt];
		// There are only a few fields per document. We opt for a full scan
		// rather then requiring that they be ordered. We need to read through
		// all of the fields anyway to get to the tvf pointers.
		long number = 0;
		int found = -1;
		int i;
		for (i = 0; i < fieldCount; i++) {
			if(tvdFormat == TERM_VECTORS_WRITER_FORMAT_VERSION)
			{
				number = [tvd readVInt];
			}
			else
			{
				number += [tvd readVInt];
			}
			
			if (number == fieldNumber)
				found = i;
		}
		// This field, although valid in the segment, was not found in this
		// document
		if (found != -1) {
			// Compute position in the tvf file
			position = 0;
			int i;
			for (i = 0; i <= found; i++)
				position += [tvd readVLong];
			
			result = [self readTermVector: field
								  pointer: position];
		} else {
			NSLog(@"Field not found");
		}
    } else {
		NSLog(@"No tvx file");
    }
    return result;
}

/**
* Return all term vectors stored for this document or null if the could not be read in.
 * 
 * @param docNum The document number to retrieve the vector for
 * @return All term frequency vectors
 * @throws IOException if there is an error reading the term vector files 
 */
- (NSArray *) termFrequencyVectors: (int) docNum
{
	NSArray *result = nil;;
    // Check if no term vectors are available for this segment at all
    if (tvx != nil) {
		//We need to offset by
		[tvx seekToFileOffset: ((docNum * 8L) + TERM_VECTORS_WRITER_FORMAT_SIZE)];
		long long position = [tvx readLong];
		
		[tvd seekToFileOffset: position];
		long fieldCount = [tvd readVInt];
		
		// No fields are vectorized for this document
		if (fieldCount != 0) {
			long number = 0;
			NSMutableArray *fields = [[NSMutableArray alloc] init];
			
			int i;
			for (i = 0; i < fieldCount; i++) {
				if(tvdFormat == TERM_VECTORS_WRITER_FORMAT_VERSION)
					number = [tvd readVInt];
				else
					number += [tvd readVInt];
				
				[fields addObject: [fieldInfos fieldName: number]];
			}
			
			// Compute position in the tvf file
			position = 0;
			NSMutableArray *tvfPointers = [[NSMutableArray alloc] init];
			int ii;
			for (ii = 0; ii < fieldCount; ii++) {
				position += [tvd readVLong];
				[tvfPointers addObject: [NSNumber numberWithLongLong: position]];
			}
			
			result = [self readTermVectors: fields
								  pointers: tvfPointers];
			DESTROY(fields);
			DESTROY(tvfPointers);
		}
    } else {
		NSLog(@"No tvx file");
    }
    return result;
}

- (NSArray *) readTermVectors: (NSArray *) fields 
					 pointers: (NSArray *) tvfPointers
{
	NSMutableArray *res = [[NSMutableArray alloc] init];
	int i;
	for (i = 0; i < [fields count]; i++) {
		[res addObject: [self readTermVector: [fields objectAtIndex: i]
									 pointer: [[tvfPointers objectAtIndex: i] longLongValue]]];
    }
    return AUTORELEASE(res);
}

/**
* 
 * @param field The field to read in
 * @param tvfPointer The pointer within the tvf file where we should start reading
 * @return The TermVector located at that position
 * @throws IOException
 */ 
/** LuceneKit implementation:
* If positions and/or offset are not stored,
* a empty array will be inserted instead nil as in Java.
*/
- (LCSegmentTermVector *) readTermVector: (NSString *) field
                                 pointer: (long long) tvfPointer
{
    // Now read the data from specified position
    //We don't need to offset by the FORMAT here since the pointer already includes the offset
    [tvf seekToFileOffset: tvfPointer];
	
    long numTerms = [tvf readVInt];
    // If no terms - return a constant empty termvector. However, this should never occur!
    if (numTerms == 0) 
    {
		return AUTORELEASE([[LCSegmentTermVector alloc] initWithField: field
																terms: nil
															termFreqs: nil]);
    }
    
    BOOL storePositions;
    BOOL storeOffsets;
    
    if(tvfFormat == TERM_VECTORS_WRITER_FORMAT_VERSION){
		char bits = [tvf readByte];
		storePositions = (bits & STORE_POSITIONS_WITH_TERMVECTOR) != 0;
		storeOffsets = (bits & STORE_OFFSET_WITH_TERMVECTOR) != 0;
    }
    else{
		[tvf readVInt];
		storePositions = NO;
		storeOffsets = NO;
    }
	
    NSMutableArray *terms = [[NSMutableArray alloc] init];
    NSMutableArray *termFreqs = [[NSMutableArray alloc] init];
    
    //  we may not need these, but declare them
    NSMutableArray *positions = nil;
    NSMutableArray *offsets = nil;
    if(storePositions)
      positions = AUTORELEASE([[NSMutableArray alloc] init]);
    if(storeOffsets)
      offsets = AUTORELEASE([[NSMutableArray alloc] init]);
    
    long start = 0;
    long deltaLength = 0;
    long totalLength = 0;
    NSMutableString *buffer = [[NSMutableString alloc] init];
    NSString *previousString = @"";
    
    int i;
    for (i = 0; i < numTerms; i++) {
		start = [tvf readVInt];
		deltaLength = [tvf readVInt];
		totalLength = start + deltaLength;
		if ([buffer length] < totalLength)
		{
			NSRange r = NSMakeRange(0, [previousString length]);;
			[buffer setString: [previousString substringWithRange: r]];
		}
		[tvf readChars: buffer start: start length: deltaLength];
		[terms addObject: [buffer substringToIndex: totalLength]];
		previousString = [terms lastObject];
		long freq = [tvf readVInt];
		[termFreqs addObject: [NSNumber numberWithLong: freq]];
		
		NSMutableArray *pos = [[NSMutableArray alloc] init];
		if (storePositions) { //read in the positions
							  //[positions addObject: pos];
			long prevPosition = 0;
			int j;
			for (j = 0; j < freq; j++)
			{
				[pos addObject: [NSNumber numberWithLong: prevPosition+[tvf readVInt]]];
				prevPosition = [[pos lastObject] longValue];
			}
		}
		[positions addObject: pos];
		DESTROY(pos);
		
		NSMutableArray *offs = [[NSMutableArray alloc] init];
		if (storeOffsets) {
			//[offsets addObject: offs];
			long prevOffset = 0;
			int j;
			for (j = 0; j < freq; j++) {
				long startOffset = prevOffset + [tvf readVInt];
				long endOffset = startOffset + [tvf readVInt];
				[offs addObject: AUTORELEASE([[LCTermVectorOffsetInfo alloc] initWithStartOffset: startOffset endOffset: endOffset])];
				prevOffset = endOffset;
			}
		}
		[offsets addObject: offs];
		DESTROY(offs);
    }
    
    LCSegmentTermVector *tv;
    if (storePositions || storeOffsets){
		tv = [[LCSegmentTermPositionVector alloc] initWithField: field
														  terms: terms
													  termFreqs: termFreqs
													  positions: positions
														offsets: offsets];
    }
    else {
		tv = [[LCSegmentTermVector alloc] initWithField: field
												  terms: terms
											  termFreqs: termFreqs];
    }
    DESTROY(buffer);
    DESTROY(terms);
    DESTROY(termFreqs);
    return AUTORELEASE(tv);
}

- (void) setTVX: (LCIndexInput *) vx
{
	ASSIGN(tvx, vx);
}

- (void) setTVD: (LCIndexInput *) vd
{
	ASSIGN(tvd, vd);
}

- (void) setTVF: (LCIndexInput *) vf
{
	ASSIGN(tvf, vf);
}

/* For clone */
- (void) setSize: (long) s
{
	size = s;
}

- (void) setTVDFormat: (long) f
{
	tvdFormat = f;
}

- (void) setTVFFormat: (long) f
{
	tvfFormat = f;
}

- (void) setFieldInfos: (LCFieldInfos *) fi
{
	ASSIGN(fieldInfos, fi);
}

- (id) copyWithZone: (NSZone *) zone;
{
    
    if (tvx == nil || tvd == nil || tvf == nil)
		return nil;
    
    LCTermVectorsReader *clone = [[LCTermVectorsReader allocWithZone: zone] init];
    [clone setTVX: AUTORELEASE([tvx copy])];
    [clone setTVD: AUTORELEASE([tvd copy])];
    [clone setTVF: AUTORELEASE([tvf copy])];
    [clone setSize: size];
    [clone setTVDFormat: tvdFormat];
    [clone setTVFFormat: tvfFormat];
    [clone setFieldInfos: fieldInfos];
    
    return clone;
}

@end
