#include "LCDocumentWriter.h"
#include "LCTermVectorOffsetInfo.h"
#include "LCTerm.h"
#include "LCTermBuffer.h"
#include "LCTermInfo.h"
#include "LCTermInfosWriter.h"
#include "LCTermVectorsWriter.h"
#include "LCFieldInfos.h"
#include "LCFieldsWriter.h"
#include "LCStringReader.h"
#include "GNUstep.h"

@interface LCPosting: NSObject // info about a Term in a doc
{       
	LCTerm *term; // the Term
	long freq; // its frequency in doc
	NSMutableArray *positions; //int // positions it occurs at
	NSMutableArray *offsets; // LCTermVectorOffsetInfo
}       

- (id) initWithTerm: (LCTerm *) t
		   position: (long) position
			 offset: (LCTermVectorOffsetInfo *) offset;
- (LCTerm *) term;
- (long) freq;
- (NSMutableArray *) positions;
- (NSMutableArray *) offsets;
- (void) setFreq: (long) f;
@end

@implementation LCPosting

- (id) initWithTerm: (LCTerm *) t
		   position: (long) position
			 offset: (LCTermVectorOffsetInfo *) offset
{
	self = [self init];
	ASSIGN(term, t);
	freq = 1;
	positions = [[NSMutableArray alloc] initWithObjects: [NSNumber numberWithLong: position], nil];
	if(offset != nil){
		offsets = [[NSMutableArray alloc] initWithObjects: offset, nil];
	}
	else
	{
		offsets = nil;
	}
	return self;
}

- (void) dealloc
{
	DESTROY(term);
	DESTROY(positions);
	DESTROY(offsets);
	[super dealloc];
}

- (NSComparisonResult) compare: (id) other
{
	return [[self term] compare: [(LCPosting *)other term]];
}

- (LCTerm *) term { return term; }
- (long) freq { return freq; }
- (NSMutableArray *) positions { return positions; }
- (NSMutableArray *) offsets { return offsets; }
- (void) setFreq: (long) f { freq = f; }

@end

@interface LCDocumentWriter (LCPrivate)
- (void) invertDocument: (LCDocument *) doc;
- (void) addField: (NSString *) field
             text: (NSString *) text
         position: (long) position
           offset: (LCTermVectorOffsetInfo *) offset;
- (NSArray *) sortPostingTable;
- (void) writePostings: (NSArray *) postings 
			   segment: (NSString *) segment;
- (void) writeNorms: (NSString *) segment;
@end

@implementation LCDocumentWriter
- (id) init
{
	self = [super init];
	termIndexInterval = DEFAULT_TERM_INDEX_INTERVAL;
	return self;
}

/** This ctor used by test code only.
*
* @param directory The directory to write the document information to
* @param analyzer The analyzer to use for the document
* @param similarity The Similarity function
* @param maxFieldLength The maximum number of tokens a field may have
*/ 
- (id) initWithDirectory: (id <LCDirectory>) dir
				analyzer: (LCAnalyzer *) ana
              similarity: (LCSimilarity *) sim
		  maxFieldLength: (int) max
{
	self = [self init];
	ASSIGN(directory, dir);
	ASSIGN(analyzer, ana);
	ASSIGN(similarity, sim);
	maxFieldLength = max;
	return self;
}

- (id) initWithDirectory: (id <LCDirectory>) dir
				analyzer: (LCAnalyzer *) ana
			 indexWriter: (LCIndexWriter *) iw
{
	self = [self init];
	ASSIGN(directory, dir);
	ASSIGN(analyzer, ana);
	ASSIGN(similarity, [iw similarity]);
	maxFieldLength = [iw maxFieldLength];
	termIndexInterval = [iw termIndexInterval];
	return self;
}

- (void) dealloc
{
	DESTROY(analyzer);
	DESTROY(directory);
	DESTROY(similarity);
	[super dealloc];
}

- (void) addDocument: (NSString *) segment
			document: (LCDocument *) doc
{
	CREATE_AUTORELEASE_POOL(x);
	// write field names
        NSAssert(!fieldInfos,@"Already fieldInfos");
	fieldInfos = [[LCFieldInfos alloc] init];
	[fieldInfos addDocument: doc];
	[fieldInfos write: directory name: [segment stringByAppendingPathExtension: @"fnm"]];
	
    // write field values
	LCFieldsWriter *fieldsWriter = [[LCFieldsWriter alloc] initWithDirectory: directory segment: segment fieldInfos: fieldInfos];
	[fieldsWriter addDocument: doc];
	[fieldsWriter close];
	DESTROY(fieldsWriter);
	
    // invert doc into postingTable
        NSAssert(!postingTable,@"Already postingTable");
	postingTable = [[NSMutableDictionary alloc] init];
	fieldLengths = calloc([fieldInfos size], sizeof(long long));
	fieldPositions = calloc([fieldInfos size], sizeof(long long));
	fieldOffsets = calloc([fieldInfos size], sizeof(long long));
	fieldBoosts = calloc([fieldInfos size], sizeof(float));

	int i, count = [fieldInfos size];
	for(i = 0; i < count; i++)
	{
		fieldBoosts[i] = [doc boost];
	}
	
	[self invertDocument: doc];
    // sort postingTable into an array
	NSArray *postings = [self sortPostingTable];

    // write postings
    [self writePostings: postings segment: segment];
	
    // write norms of indexed fields
    [self writeNorms: segment];

    free(fieldLengths);
    free(fieldPositions);
    free(fieldOffsets);
    free(fieldBoosts);
    DESTROY(postingTable);
    DESTROY(fieldInfos);
	DESTROY(x);
}

// Tokenizes the fields of a document into Postings.
- (void) invertDocument: (LCDocument *) doc
{
	NSEnumerator *fields = [doc fieldEnumerator];
	LCField *field = nil;
	while ((field = [fields nextObject]))
	{
		NSString *fieldName = [field name];
		int fieldNumber = [fieldInfos fieldNumber: fieldName];
		long long length = 0, position = 0, offset = 0;

		length = fieldLengths[fieldNumber];
		position = fieldPositions[fieldNumber];
		if (length > 0) position += [analyzer positionIncrementGap: fieldName];
		offset = fieldOffsets[fieldNumber];
		
		if ([field isIndexed]) {
			if (![field isTokenized]) {		  // un-tokenized field
				NSString *stringValue = [field string];
				if([field isOffsetWithTermVectorStored])
				{
					LCTermVectorOffsetInfo *tvoi = [[LCTermVectorOffsetInfo alloc] initWithStartOffset: offset endOffset: offset + [stringValue length]];
					[self addField: fieldName
							  text: stringValue
						  position: position++
							offset: tvoi];
					DESTROY(tvoi);
				}
				else
					[self addField: fieldName
							  text: stringValue
						  position: position++
							offset: nil];
				
				offset += [stringValue length];
				length++;
			} 
			else 
			{
				id <LCReader> reader = nil;  // find or make Reader
				if ([field reader] != nil)
					ASSIGN(reader, [field reader]);
				else if ([field string] != nil)
					ASSIGN(reader, AUTORELEASE([[LCStringReader alloc] initWithString: [field string]]));
				else
				{
					NSLog(@"field must have either String or Reader value");
					return;
				}
				
				// Tokenize field and add to postingTable
				LCTokenStream *stream = [analyzer tokenStreamWithField: fieldName
																reader: reader];
				DESTROY(reader);
				LCToken *t, *lastToken = nil;
				
				for (t = [stream nextToken]; t != nil; t = [stream nextToken]) {
					position += ([t positionIncrement] - 1);
					
					if([field isOffsetWithTermVectorStored])
					{
						LCTermVectorOffsetInfo *tvoi = [[LCTermVectorOffsetInfo alloc] initWithStartOffset: [t startOffset] endOffset: offset + [t endOffset]];
						[self addField: fieldName
								  text: [t termText]
							  position: position++
								offset: tvoi];
						DESTROY(tvoi);
					}
					else
						[self addField: fieldName
								  text: [t termText]
							  position: position++
								offset: nil];
					
					lastToken = t;
					if (++length > maxFieldLength) {
						break;
					}
				}
				
				if(lastToken != nil)
					offset += [lastToken endOffset] + 1;
				
				[stream close];
				stream = nil;
			}
			
		fieldLengths[fieldNumber] = length;
		fieldPositions[fieldNumber] = position;
		fieldOffsets[fieldNumber] = offset;
			
			float newBoosts = fieldBoosts[fieldNumber] * [field boost];
			fieldBoosts[fieldNumber] = newBoosts;
		} /* if tokenized */
	} /* while */
}

//private final Term termBuffer = new Term("", ""); // avoid consing

- (void) addField: (NSString *) field
             text: (NSString *) text
		 position: (long) position
		   offset: (LCTermVectorOffsetInfo *) offset
{
	LCTerm *termBuffer = [[LCTerm alloc] init];
	[termBuffer setField: field];
	[termBuffer setText: text];

	LCPosting *ti = (LCPosting*) [postingTable objectForKey: termBuffer];
    if (ti != nil) {				  // word seen before
		int freq = [ti freq];
		if ([[ti positions] count] == freq) {	  // positions array is full
			
			[[ti positions] addObject: [NSNumber numberWithLong: position]];
		}
		else 
			[[ti positions] replaceObjectAtIndex: freq withObject: [NSNumber numberWithLong: position]];		  // add new position
		
		if (offset != nil) {
			if ([[ti offsets] count]== freq){
				[[ti offsets] addObject: offset];
			}
			else
				[[ti offsets] replaceObjectAtIndex: freq withObject: offset];
		}
		[ti setFreq: (freq + 1)];			  // update frequency
    } else {					  // word not seen before
		LCTerm *term = [[LCTerm alloc] initWithField: field text: text];
		[postingTable setObject: AUTORELEASE([[LCPosting alloc] initWithTerm: term
														position: position
                                                                        offset: offset])
						 forKey: term];
		DESTROY(term);
    }
	DESTROY(termBuffer);
}

- (NSArray *) sortPostingTable
{
    // copy postingTable into an array
    NSMutableArray *array = [[NSMutableArray alloc] init];
    NSEnumerator *e = [postingTable objectEnumerator];
    id object;
    while((object = [e nextObject]))
    {
		[array addObject: object];
    }
	
    // sort the array
    [array sortUsingSelector: @selector(compare:)];
	
    return AUTORELEASE(array);
}

- (void) writePostings: (NSArray *) postings 
			   segment: (NSString *) segment
{
	LCIndexOutput *freq = nil, *prox = nil;
	LCTermInfosWriter *tis = nil;
	LCTermVectorsWriter *termVectorWriter = nil;
	
	//open files for inverse index storage
	NSString *name = [segment stringByAppendingPathExtension: @"frq"];
	freq = [directory createOutput: name];
	name = [segment stringByAppendingPathExtension: @"prx"];
	prox = [directory createOutput: name];
	tis = [[LCTermInfosWriter alloc] initWithDirectory: directory
											   segment: segment
											fieldInfos: fieldInfos
											  interval: termIndexInterval];
	AUTORELEASE(tis);
	LCTermInfo *ti = [[LCTermInfo alloc] init];
	AUTORELEASE(ti);
	NSString *currentField = nil;
	
	int i;
	for (i = 0; i < [postings count]; i++) {
		LCPosting *posting = [postings objectAtIndex: i];
		
		// add an entry to the dictionary with pointers to prox and freq files
		[ti setDocumentFrequency: 1];
		[ti setFreqPointer: [freq offsetInFile]];
		[ti setProxPointer: [prox offsetInFile]];
		[ti setSkipOffset: -1];
		[tis addTerm: [posting term] termInfo: ti];
		
		// add an entry to the freq file
		long postingFreq = [posting freq];
		if (postingFreq == 1)				  // optimize freq=1
		{
			[freq writeVInt: 1];			  // set low bit of doc num.
		}
		else {
			[freq writeVInt: 0];			  // the document number
			[freq writeVInt: postingFreq];			  // frequency in doc
		}
		
		long lastPosition = 0;			  // write positions
		NSArray *positions = [posting positions];
		int j;
		for (j = 0; j < postingFreq; j++) {		  // use delta-encoding
			long position = [[positions objectAtIndex: j] longValue];
			[prox writeVInt: position - lastPosition];
			lastPosition = position;
		}
		
		// check to see if we switched to a new field
		NSString *termField = [[posting term] field];
		if (currentField != termField) {
			// changing field - see if there is something to save
			currentField = termField;
			LCFieldInfo *fi = [fieldInfos fieldInfo: currentField];
			if ([fi isTermVectorStored]) {
				if (termVectorWriter == nil) {
					termVectorWriter = [[LCTermVectorsWriter alloc] initWithDirectory: directory segment: segment fieldInfos: fieldInfos];
					AUTORELEASE(termVectorWriter);
					[termVectorWriter openDocument];
				}
				[termVectorWriter openField: currentField];
				
			} else if (termVectorWriter != nil) {
				[termVectorWriter closeField];
			}
		}
		if (termVectorWriter != nil && [termVectorWriter isFieldOpen]) {
			[termVectorWriter addTerm: [[posting term] text]
								 freq: postingFreq
							positions: [posting positions]
							  offsets: [posting offsets]];
		}
	}
	if (termVectorWriter != nil)
        [termVectorWriter closeDocument];
	
	// make an effort to close all streams we can but remember and re-throw
	// the first exception encountered in this process
	if (freq) [freq close];
	if (prox) [prox close];
	if (tis) [tis close];
	if (termVectorWriter) [termVectorWriter close];
}

- (void) writeNorms: (NSString *) segment
{
	int n;
	for(n = 0; n < [fieldInfos size]; n++){
		LCFieldInfo *fi = [fieldInfos fieldInfoWithNumber: n];
		if([fi isIndexed] && (![fi omitNorms])){
			float norm = fieldBoosts[n] * [similarity lengthNorm: [fi name] numberOfTerms: fieldLengths[n]];
			NSString *name = [NSString stringWithFormat: @"%@.f%d", segment, n];
			LCIndexOutput *norms = [directory createOutput: name];
			[norms writeByte: [LCSimilarity encodeNorm: norm]];
			[norms close];
		}
	}
}

@end

