#include "LCTermInfosWriter.h"
#include "NSString+Additions.h"
#include "GNUstep.h"

/** This stores a monotonically increasing set of <Term, TermInfo> pairs in a
Directory.  A TermInfos can be written once, in order.  */
@interface LCTermInfosWriter (LCPrivate)
- (id) initWithDirectory: (id <LCDirectory>) directory
				 segment: (NSString *) segment
			  fieldInfos: (LCFieldInfos *) fis
				interval: (int) interval
				 isIndex: (BOOL) isIndex;
@end

@implementation LCTermInfosWriter

- (id) init
{
	self = [super init];
	ASSIGN(lastTerm, AUTORELEASE([[LCTerm alloc] initWithField: @"" text: @""]));
	ASSIGN(lastTi, AUTORELEASE([[LCTermInfo alloc] init]));
	size = 0;
	
	// TODO: the default values for these two parameters should be settable from
	// IndexWriter.  However, once that's done, folks will start setting them to
	// ridiculous values and complaining that things don't work well, as with
	// mergeFactor.  So, let's wait until a number of folks find that alternate
	// values work better.  Note that both of these values are stored in the
	// segment, so that it's safe to change these w/o rebuilding all indexes.
	
	/** Expert: The fraction of terms in the "dictionary" which should be stored
		* in RAM.  Smaller values use more memory, but make searching slightly
		* faster, while larger values use less memory and make searching slightly
		* slower.  Searching is typically not dominated by dictionary lookup, so
		* tweaking this is rarely useful.*/
	indexInterval = 128;
	
	/** Expert: The fraction of {@link TermDocs} entries stored in skip tables,
		* used to accellerate {@link TermDocs#skipTo(int)}.  Larger values result in
		* smaller indexes, greater acceleration, but fewer accelerable cases, while
		* smaller values result in bigger indexes, less acceleration and more
		* accelerable cases. More detailed experiments would be useful here. */
	skipInterval = 16;
	
	lastIndexPointer = 0;
	isIndex = NO;
	
	other = nil;
	return self;
}

- (id) initWithDirectory: (id <LCDirectory>) directory
				 segment: (NSString *) segment
			  fieldInfos: (LCFieldInfos *) fis
				interval: (int) interval
{
	self = [self initWithDirectory: directory
						   segment: segment
						fieldInfos: fis
						  interval: interval
						   isIndex: NO];
        // Other is own only for !isIndex
	ASSIGN(other, AUTORELEASE([[LCTermInfosWriter alloc] initWithDirectory: directory
													   segment: segment
													fieldInfos: fis
													  interval: interval
													   isIndex: YES]));
	[other setOther: self];
	return self;
}

- (void) setOther: (LCTermInfosWriter *) o
{
	other = o; //Don't retain
}

- (id) initWithDirectory: (id <LCDirectory>) directory
				 segment: (NSString *) segment
			  fieldInfos: (LCFieldInfos *) fis
				interval: (int) interval
				 isIndex: (BOOL) isi
{
	self = [self init];
    indexInterval = interval;
    ASSIGN(fieldInfos, fis);
    isIndex = isi;
    NSString *s;
    if (isIndex)
    {
	    s = [segment stringByAppendingPathExtension: @"tii"];
    }
    else
    {
	    s = [segment stringByAppendingPathExtension: @"tis"];
    }
    ASSIGN(output, [directory createOutput: s]);
    [output writeInt: LCTermInfos_FORMAT]; //write format
    [output writeLong: 0];                          // leave space for size
    [output writeInt: indexInterval];             // write indexInterval
    [output writeInt: skipInterval];              // write skipInterval
    return self;
}

- (void) dealloc
{
	DESTROY(lastTerm);
	DESTROY(lastTi);
	if (!isIndex)
          DESTROY(other);
	DESTROY(fieldInfos);
	DESTROY(output);
	[super dealloc];
}

/** Adds a new <Term, TermInfo> pair to the set.
Term must be lexicographically greater than all previous Terms added.
TermInfo pointers must be positive and greater than all previous.*/
- (void) addTerm: (LCTerm *) term termInfo: (LCTermInfo *) ti
{
	//NSLog(@"LCTermInfosWriter addTerm %@", term);
	if (!isIndex && [term compare: lastTerm] != NSOrderedDescending)
    {
        NSLog(@"lastTerm %@, term %@", lastTerm, term);
	    NSLog(@"term out of order");
	    return;
    }
    if ([ti freqPointer] < [lastTi freqPointer])
    {
	    NSLog(@"freqPointer out of order");
	    return;
    }
    if ([ti proxPointer] < [lastTi proxPointer])
    {
	    NSLog(@"proxPointer out of order");
	    return;
    }
	
    if (!isIndex && size % indexInterval == 0)
    {
		/* Take care the first term while lastTerm == nil */
		/* LuceneKit: lucene doesn't care this */
		if (size == 0)
			[other addTerm: term termInfo: ti];
		else
			[other addTerm: lastTerm termInfo:  lastTi];     // add an index term
    }
	
    [self writeTerm: term];                                    // write term
    [output writeVInt: [ti documentFrequency]];             // write doc freq
    long delta = [ti freqPointer] - [lastTi freqPointer];
    [output writeVLong: delta]; // write pointers
    delta = [ti proxPointer] - [lastTi proxPointer];
    [output writeVLong: delta];
	
    if ([ti documentFrequency] >= skipInterval) {
		[output writeVInt: [ti skipOffset]];
    }
	
    if (isIndex) {
		[output writeVLong: [[other output] offsetInFile] - lastIndexPointer];
		lastIndexPointer = [[other output] offsetInFile]; // write pointer
    }
	
    [lastTi setTermInfo: ti];
    size++;
}

- (LCIndexOutput *) output
{
	return output;
}

- (void) writeTerm: (LCTerm *) term
{
	int start = [[lastTerm text] positionOfDifference: [term text]];
	int length = [[term text] length] - start;
	
    [output writeVInt: start];                   // write shared prefix length
    [output writeVInt: length];                  // write delta length
    [output writeChars: [term text] start:  start length: length];  // write delta chars
	
    [output writeVInt: [fieldInfos fieldNumber: [term field]]]; // write field num
	
    /* Cache lastTerm. DO NOT use ASSIGN() because term might change */
    //ASSIGN(lastTerm, term);
    [lastTerm setField: [term field]];
    [lastTerm setText: [term text]];
}



/** Called to complete TermInfos creation. */
- (void) close
{
	[output seekToFileOffset: 4];          // write size after format
	[output writeLong: size];
	[output close];
	
    if (!isIndex)
	    [other close];
}

- (int) skipInterval
{
	return skipInterval;
}

@end
