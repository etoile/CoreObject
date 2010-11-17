#include "LCTerm.h"
#include "LCTermInfo.h"
#include "LCFieldInfos.h"
#include "LCTermInfosWriter.h"
#include "LCTermInfosReader.h"
#include "LCSegmentTermEnum.h"
#include "LCIndexWriter.h"
#include "LCRAMDirectory.h"
#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>

@interface TestTermInfos: NSObject <UKTest>
@end

@implementation TestTermInfos

- (void) testTermInfos
{
	/* Need to be in ordered */
	NSArray *words = [NSArray arrayWithObjects:
		@"AAMembrane", @"ABproteins", @"ACaccount", @"ADfor",
		@"AEabout", @"AF25%", @"AGof", @"AHthe", 
		@"AIencoded", @"AJby", @"AKgenome",
		@"ALThey", @"AMplay", @"ANkey", @"AProles", @"AQin",
		@"ARa", @"ASvariety", @"ATof", @"AWcellular", @"AXprocesses",
		@"AYincluding", @"AZenergy", @"BAand", @"BBsignal", @"BCtransduction",
		@"BDComprehensive", @"BEunderstanding",
		@"BFmolecular", @"BGmechanisms", @"BHthese", @"BIfundamental",
		@"BJbiological", @"BKmembrane-associated", 
		@"BLprocesses", @"BMcannot", @"BNattained", @"BOunless",
		@"BPatomic", @"BQstructures", @"BSinvolved", @"BTare", @"BWknown", nil];
	
	NSDate *start = [NSDate date];
	NSMutableArray *keys = [[NSMutableArray alloc] init];
	int i, count = [words count];
	for(i = 0; i < count; i++)
		[keys addObject: [[LCTerm alloc] initWithField: @"word"
												  text:  [words objectAtIndex: i]]]; 
	
	NSDate *end = [NSDate date];
	
	NSLog(@"%f seconds to read %d words", [end timeIntervalSince1970] - [start timeIntervalSince1970], [words count]);
	
    start = [NSDate date];
	
    srandom(1251971);
    long fp = ((int)random() & 0xF) + 1;
    long pp = ((int)random() & 0xF) + 1;
    NSMutableArray *docFreqs = [[NSMutableArray alloc] init];
    NSMutableArray *freqPointers = [[NSMutableArray alloc] init];
    NSMutableArray *proxPointers = [[NSMutableArray alloc] init];
    count = [keys count];
    for (i = 0; i < count; i++) {
		[docFreqs addObject: [NSNumber numberWithInt: ((int)random()) & 0xF + 1]];
		[freqPointers addObject: [NSNumber numberWithLong: fp]];
		[proxPointers addObject: [NSNumber numberWithLong: pp]];
		fp += ((int)random() & 0xF) + 1;;
		pp += ((int)random() & 0xF) + 1;;
    }
	
    end = [NSDate date];
	
	NSLog(@"%f seconds to generate values", [end timeIntervalSince1970] - [start timeIntervalSince1970]);
	
    start = [NSDate date];
	
    // FIXME: should test on real file syste (LCFSDirecotry)
    id <LCDirectory> store = [[LCRAMDirectory alloc] init];
    LCFieldInfos *fis = [[LCFieldInfos alloc] init];
	
    LCTermInfosWriter *writer = [[LCTermInfosWriter alloc]
	     initWithDirectory: store
				   segment: @"words"
				fieldInfos: fis
				  interval: DEFAULT_TERM_INDEX_INTERVAL];
    [fis addName: @"word"  isIndexed: NO];
	
    count = [keys count];
    for (i = 0; i < count; i++)
    {
		LCTermInfo *termInfo = [[LCTermInfo alloc] initWithDocFreq: [[docFreqs objectAtIndex: i] intValue]
													   freqPointer: [[freqPointers objectAtIndex: i] longValue]
													   proxPointer: [[proxPointers objectAtIndex: i] longValue]];
		[writer addTerm: [keys objectAtIndex: i]
			   termInfo: termInfo];
    }
	
    [writer close];
	
    end = [NSDate date];
	
	NSLog(@"%f seconds to write table.", [end timeIntervalSince1970] - [start timeIntervalSince1970]);
	NSLog(@"Table occupies %lld bytes", [store fileLength: @"words.tis"]);
	
    start = [NSDate date];
	
    LCTermInfosReader *reader = [[LCTermInfosReader alloc] initWithDirectory: store segment: @"words" fieldInfos: fis];
	
    end = [NSDate date];
	
	NSLog(@"%f seconds to open table.", [end timeIntervalSince1970] - [start timeIntervalSince1970]);
	
    start = [NSDate date];
	
    LCSegmentTermEnumerator *enumerator = [reader termEnumerator];
    for (i = 0; i < [keys count]; i++) {
		[enumerator hasNextTerm];
		LCTerm *key = (LCTerm *)[keys objectAtIndex: i];
//		UKObjectsEqual(key, [enumerator term]); // Doesn't work
		UKTrue([key isEqual: [enumerator term]]);
		
		LCTermInfo *ti = [enumerator termInfo];
		UKIntsEqual([ti documentFrequency], [[docFreqs objectAtIndex: i] intValue]);
		UKIntsEqual([ti freqPointer], [[freqPointers objectAtIndex: i] longValue]);
		UKIntsEqual([ti proxPointer], [[proxPointers objectAtIndex: i] longValue]);
    }
    end = [NSDate date];
	
	NSLog(@"%f seconds to iterate over %d words.", [end timeIntervalSince1970] - [start timeIntervalSince1970], [keys count]);
	
    start = [NSDate date];
	
    for (i = 0; i < [keys count]; i++) {
		LCTerm *key = (LCTerm *)[keys objectAtIndex: i];
		LCTermInfo *ti = [reader termInfo: key];
		UKIntsEqual([ti documentFrequency], [[docFreqs objectAtIndex: i] longValue]);
		UKIntsEqual([ti freqPointer], [[freqPointers objectAtIndex: i] longLongValue]);
		UKIntsEqual([ti proxPointer], [[proxPointers objectAtIndex: i] longLongValue]);
    }
    
    end = [NSDate date];
    
    NSLog(@"%f average seconds per lookup.", ([end timeIntervalSince1970] - [start timeIntervalSince1970])/[keys count]);
    
    LCTermEnumerator *e = [reader termEnumeratorWithTerm: [[LCTerm alloc] initWithField: @"word" text: @"AP"]];
    UKStringsEqual([[e term] text], @"AProles");
    [reader close];
    [store close];
}

@end
