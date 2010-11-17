#include "LCRAMDirectory.h"
#include "LCTermVectorsWriter.h"
#include "LCTermVectorsReader.h"
#include "LCFieldInfos.h"
#include "LCTermVectorOffsetInfo.h"
#include "LCTermFreqVector.h"
#include "LCTermPositionVector.h"
#include "GNUstep.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>

@interface TestTermVectorsReader: NSObject <UKTest>
{
	LCTermVectorsWriter *writer;
	//Must be lexicographically sorted, will do in setup, versus trying to maintain here
	NSArray *testFields;
	NSArray *testFieldsStorePos;
	NSArray *testFieldsStoreOff;
	NSMutableArray *testTerms;
	NSMutableArray *positions;
	NSMutableArray *offsets;
	LCRAMDirectory *dir;
	NSString *seg;
	LCFieldInfos *fieldInfos;
}
@end

@implementation TestTermVectorsReader

- (id) init
{
    self = [super init];
    writer = nil;
    //Must be lexicographically sorted, will do in setup, versus trying to maintain here
    testFields = [NSArray arrayWithObjects: @"f1", @"f2", @"f3", nil];
    testFieldsStorePos = [NSArray arrayWithObjects: [NSNumber numberWithBool: YES], [NSNumber numberWithBool: NO], [NSNumber numberWithBool: YES], [NSNumber numberWithBool: NO], nil];
    testFieldsStoreOff = [NSArray arrayWithObjects: [NSNumber numberWithBool: YES], [NSNumber numberWithBool: NO], [NSNumber numberWithBool: NO], [NSNumber numberWithBool: YES], nil];
    testTerms = [NSMutableArray arrayWithObjects: @"this", @"is", @"a", @"test", nil];
    dir = [[LCRAMDirectory alloc] init];
    seg = @"testSegment";
    fieldInfos = [[LCFieldInfos alloc] init];
    
    int i, j, k;
    for(i = 0; i < [testFields count]; i++)
    {
		BOOL storePos = [[testFieldsStorePos objectAtIndex: i] boolValue];
		BOOL storeOff = [[testFieldsStoreOff objectAtIndex: i] boolValue];
		[fieldInfos addName: [testFields objectAtIndex: i]
                  isIndexed: YES
		 isTermVectorStored: YES
                  isStorePositionWithTermVector: storePos
isStoreOffsetWithTermVector: storeOff];
	}
    positions = [[NSMutableArray alloc] init];
    offsets = [[NSMutableArray alloc] init];
    for (i = 0 ; i < [testTerms count]; i++)
    {
		NSMutableArray *a = [[NSMutableArray alloc] init];
		for (j = 0; j < 3; j++)
		{
			[a addObject :[NSNumber numberWithInt: (int)(j*10+random()*10)]];
		}
        [positions addObject: a];
        DESTROY(a);
		a = [[NSMutableArray alloc] init];
		for(j = 0; j < 3; j++)
		{
			[a addObject: [[LCTermVectorOffsetInfo alloc] initWithStartOffset: j * 10 endOffset: j * 10+[(NSString *)[testTerms objectAtIndex: i] length]]];
		}
		[offsets addObject: a];
		DESTROY(a);
    }
    
    [testTerms sortUsingSelector: @selector(compare:)];
    for (j = 0; j < 5; j++)
    {
		writer = [[LCTermVectorsWriter alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
		[writer openDocument];
		for (k = 0; k < [testFields count]; k++)
		{
			[writer openField: [testFields objectAtIndex: k]];
			for (i = 0; i < [testTerms count]; i++)
			{
				[writer addTerm: [testTerms objectAtIndex: i]
						   freq: 3 positions: [positions objectAtIndex: i]
						offsets: [offsets objectAtIndex: i]];
			}
			[writer closeField];
		}
		[writer closeDocument];
		[writer close];
    }
	
    return self;
}

//Check to see the files were created properly in setup
- (void) testCreate
{
	UKFalse([writer isDocumentOpen]);
	UKTrue([dir fileExists: [seg stringByAppendingPathExtension: TVD_EXTENSION]]);
	UKTrue([dir fileExists: [seg stringByAppendingPathExtension: TVX_EXTENSION]]);
}

- (void) testReader
{
	LCTermVectorsReader *reader = [[LCTermVectorsReader alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	UKNotNil(reader);
	id <LCTermFrequencyVector> vector = [reader termFrequencyVector: 0 field: [testFields objectAtIndex: 0]];
	UKNotNil(vector);
	NSArray *terms = [vector allTerms];
	UKNotNil(terms);
	UKIntsEqual([terms count], [testTerms count]);
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		NSString *term = [terms objectAtIndex: i];
		UKStringsEqual(term, [testTerms objectAtIndex: i]);
	}
}

- (void) testPositionReader
{
	LCTermVectorsReader *reader = [[LCTermVectorsReader alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	UKNotNil(reader);
	id <LCTermPositionVector> vector;
	NSArray *terms;
	vector = (id <LCTermPositionVector>)[reader termFrequencyVector: 0 field: [testFields objectAtIndex: 0]];
	UKNotNil(vector);
	terms = [vector allTerms];
	UKNotNil(terms);
	UKIntsEqual([terms count], [testTerms count]);
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		NSString *term = [terms objectAtIndex: i];
		UKStringsEqual(term, [testTerms objectAtIndex: i]);
		NSArray *pos = [vector termPositions: i];
		UKNotNil(pos);
		UKIntsEqual([pos count], [[positions objectAtIndex: i] count]);
		int j;
		for (j = 0; j < [pos count]; j++)
		{
			int position = [[pos objectAtIndex: j] intValue];
			UKIntsEqual(position, [[[positions objectAtIndex: i] objectAtIndex: j] intValue]);
		}
		
		NSArray *off = [vector termOffsets: i];
		UKNotNil(off);
		UKIntsEqual([off count], [[offsets objectAtIndex: i] count]);
		for (j = 0; j < [off count]; j++)
		{
			LCTermVectorOffsetInfo *tvoi = [off objectAtIndex: j];
			UKTrue([tvoi isEqual: [[offsets objectAtIndex: i] objectAtIndex: j]]);
		}
	}
	
	id <LCTermFrequencyVector> freqVector = [reader termFrequencyVector: 0 field: [testFields objectAtIndex: 1]]; // no pos, no offset
	UKNotNil(freqVector);
	UKFalse([freqVector conformsToProtocol: @protocol(LCTermPositionVector)]);
	terms = [freqVector allTerms];
	UKNotNil(terms);
	UKIntsEqual([terms count], [testTerms count]);
	for (i = 0; i < [terms count]; i++)
	{
		NSString *term = [terms objectAtIndex: i];
		UKStringsEqual(term, [testTerms objectAtIndex: i]);
	}
}

/**
* Make sure exceptions and bad params are handled appropriately
 */ 
#if 0
public void testBadParams() {
    try {
		TermVectorsReader reader = new TermVectorsReader(dir, seg, fieldInfos);
		assertTrue(reader != null);
		//Bad document number, good field number
		reader.get(50, testFields[0]);
		assertTrue(false);      
    } catch (IOException e) {
		assertTrue(true);
    }
    try {
		TermVectorsReader reader = new TermVectorsReader(dir, seg, fieldInfos);
		assertTrue(reader != null);
		//Bad document number, no field
		reader.get(50);
		assertTrue(false);      
    } catch (IOException e) {
		assertTrue(true);
    }
    try {
		TermVectorsReader reader = new TermVectorsReader(dir, seg, fieldInfos);
		assertTrue(reader != null);
		//good document number, bad field number
		TermFreqVector vector = reader.get(0, "f50");
		assertTrue(vector == null);      
    } catch (IOException e) {
		assertTrue(false);
    }
}    
#endif

@end
