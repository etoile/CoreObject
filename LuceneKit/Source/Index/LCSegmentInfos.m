#include "LCSegmentInfos.h"
#include "GNUstep.h"

/** The file format version, a negative number. */
/* Works since counter, the old 1st entry, is always >= 0 */
#define SEGMENT_FORMAT -1

@implementation LCSegmentInfos

- (id) init
{
	self = [super init];
	counter = 0;
	/**
	 * counts how often the index has been changed by adding or deleting docs.
	 * starting with the current time in milliseconds forces to create unique version numbers.
	 */
	version = (long)([[NSDate date] timeIntervalSince1970]*1000);
	segments = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(segments);
	[super dealloc];
}

- (LCSegmentInfo *) segmentInfoAtIndex: (int) i
{
	return [segments objectAtIndex: i];
}

- (void) readFromDirectory: (id <LCDirectory>) directory
{
	LCIndexInput *input = [directory openInput: @"segments"];
	long format = [input readInt];
	if (format < 0) 
	{    // file contains explicit format info
		 // check that it is a format we can understand
		if (format < SEGMENT_FORMAT)
        {
			[NSException raise: @"LCUnknownSegmentFormatVersion"
						format: @"Unknown format version %d", format];
		}
		version = [input readLong]; // read version
		counter = [input readInt]; // read counter
	}
	else{     // file is in old format without explicit format info
        counter = format;
	}
	
	long i;
	for (i = [input readInt]; i > 0; i--) { // read segmentInfos
		NSString *is = [input readString];
        LCSegmentInfo *si = [[LCSegmentInfo alloc] initWithName: is
											  numberOfDocuments: [input readInt]
													  directory: directory];
		[segments addObject: si];
		DESTROY(si);
	}
	
	if(format >= 0){    // in old format the version number may be at the end of the file
		if ([input offsetInFile] >= [input length])
			version = (long)([[NSDate date] timeIntervalSince1970]*1000); // old file format without version number
		else
			version = [input readLong]; // read version
	}
	[input close];
}

- (void) writeToDirectory: (id <LCDirectory>) directory
{
	LCIndexOutput *output = [directory createOutput: @"segments.new"];
	[output writeInt: SEGMENT_FORMAT]; // write FORMAT
	[output writeLong: ++version]; // every write changes the index
	[output writeInt: counter]; // write counter
	[output writeInt: [segments count]]; // write infos
	int i;
	for (i = 0; i < [segments count]; i++) {
        LCSegmentInfo *si = [self segmentInfoAtIndex:i];
        [output writeString: [si name]];
        [output writeInt: [si numberOfDocuments]];
	}         
	[output close];
	
    // install new segment info
	[directory renameFile: @"segments.new" to:  @"segments"];
}

/**
* version number when this SegmentInfos was generated.
 */
- (long) version
{
	return version;
}

/**
* Current version number from segments file.
 */
+ (long) currentVersion: (id <LCDirectory>) directory
{
	LCIndexInput *input = [directory openInput: @"segments"];
	int format = 0;
	long ver = 0;
	format = [input readInt];
	if(format < 0){
		if (format < SEGMENT_FORMAT)
		{
			[NSException raise: @"LCUnknownSegmentFormatVersion"
						format: @"Unknown format version %d", format];
		}
		ver = [input readLong]; // read version
	}
	[input close];
	
	if(format < 0)
		return ver;
	
	// We cannot be sure about the format of the file.
	// Therefore we have to read the whole file and cannot simply seek to the version entry.
	
    LCSegmentInfos *sis = [[LCSegmentInfos alloc] init];
    [sis readFromDirectory: directory];
    ver = [sis version];
    DESTROY(sis);
    return ver;
}

- (int) numberOfSegments 
{
	return [segments count];
}

- (void) removeSegmentsInRange: (NSRange) range
{
	[segments removeObjectsInRange: range];
}

- (void) addSegmentInfo: (id) object
{
	[segments addObject: object];
}

- (void) setSegmentInfo: (id) object atIndex: (int) index
{
	[segments replaceObjectAtIndex: index withObject: object];
}

- (int) counter
{
	return counter;
}

- (int) increaseCounter
{
	return counter++;
}

@end
