#include "TestDocHelper.h"
#include "TestSegmentReader.h"
#include "LCSegmentReader.h"
#include "LCSegmentInfo.h"
#include "LCSegmentMerger.h"
#include "LCTerm.h"
#include "LCTermPositionVector.h"
#include "LCDocument.h"
#include "LCRAMDirectory.h"
#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCDirectory.h"

@interface TestSegmentMerger: NSObject <UKTest>
{
	//The variables for the new merged segment
	id <LCDirectory> mergedDir;
	NSString *mergedSegment;
	//First segment to be merged
	id <LCDirectory> merge1Dir;
	LCDocument *doc1;
	NSString *merge1Segment;
	LCSegmentReader *reader1;
	//Second Segment to be merged
	id <LCDirectory> merge2Dir;
	LCDocument *doc2;
	NSString *merge2Segment;
	LCSegmentReader *reader2;
}

@end

@implementation TestSegmentMerger

- (id) init
{
	self = [super init];
	//The variables for the new merged segment
	mergedDir = [[LCRAMDirectory alloc] init];
	mergedSegment = @"test";
	//First segment to be merged
	merge1Dir = [[LCRAMDirectory alloc] init];
	doc1 = [[LCDocument alloc] init];
	merge1Segment = @"test-1";
	reader1 = nil;
	//Second Segment to be merged
	merge2Dir = [[LCRAMDirectory alloc] init];
	doc2 = [[LCDocument alloc] init];
	merge2Segment = @"test-2";
	reader2 = nil;
	
	[TestDocHelper setupDoc: doc1];
	[TestDocHelper writeDirectory: merge1Dir segment: merge1Segment doc: doc1];
	[TestDocHelper setupDoc: doc2];
	[TestDocHelper writeDirectory: merge2Dir segment: merge2Segment doc: doc2];
	LCSegmentInfo *si = [[LCSegmentInfo alloc] initWithName: merge1Segment
										  numberOfDocuments: 1
												  directory: merge1Dir];
	reader1 = [LCSegmentReader segmentReaderWithInfo: si];
	si = [[LCSegmentInfo alloc] initWithName: merge2Segment
						   numberOfDocuments: 1
								   directory: merge2Dir];
	reader2 = [LCSegmentReader segmentReaderWithInfo: si];
	
	return self;
}

- (void) test
{
	UKNotNil(mergedDir);
	UKNotNil(merge1Dir);
	UKNotNil(merge2Dir);
	UKNotNil(reader1);
	UKNotNil(reader2);
}

- (void) testMerge
{
	//NSLog(@"----------------TestMerge------------------");
	LCSegmentMerger *merger = [[LCSegmentMerger alloc] initWithDirectory: mergedDir name: mergedSegment];
	[merger addIndexReader: reader1];
	[merger addIndexReader: reader2];
	int docsMerged = [merger merge];
	[merger closeReaders];
	UKIntsEqual(docsMerged, 2);      
	//Should be able to open a new SegmentReader against the new directory
	LCSegmentInfo *si = [[LCSegmentInfo alloc] initWithName: mergedSegment numberOfDocuments: docsMerged directory: mergedDir];
	LCSegmentReader *mergedReader = [LCSegmentReader segmentReaderWithInfo: si];
	UKNotNil(mergedReader);
	UKIntsEqual([mergedReader numberOfDocuments], 2);
	LCDocument *newDoc1 = [mergedReader document: 0];
	UKNotNil(newDoc1);
	//There are 2 unstored fields on the document
	UKIntsEqual([TestDocHelper numFields: newDoc1], [TestDocHelper numFields: doc1]-[[TestDocHelper unstored] count]);
	LCDocument *newDoc2 = [mergedReader document: 1];
	UKNotNil(newDoc2);
	UKIntsEqual([TestDocHelper numFields: newDoc2], [TestDocHelper numFields: doc2]-[[TestDocHelper unstored] count]);
	
	LCTerm *t = [[LCTerm alloc] initWithField: [TestDocHelper TEXT_FIELD_2_KEY] text: @"field"];
	id <LCTermDocuments> termDocs = [mergedReader termDocumentsWithTerm: t];
	UKNotNil(termDocs);
	UKTrue([termDocs hasNextDocument]);
	
	NSArray *stored = [mergedReader fieldNames: LCFieldOption_INDEXED_WITH_TERMVECTOR];
	UKNotNil(stored);
	//NSLog(@"stored size:; %d", [stored count]);
	UKIntsEqual([stored count], 2);
	
	id <LCTermFrequencyVector> vector = [mergedReader termFrequencyVector: 0 field: [TestDocHelper TEXT_FIELD_2_KEY]];
	UKNotNil(vector);
	NSArray *terms = [vector allTerms];
	UKNotNil(terms);
	UKIntsEqual([terms count], 3);
	NSArray *freqs = [vector allTermFrequencies];
	UKNotNil(freqs);
	UKTrue([vector conformsToProtocol: @protocol(LCTermPositionVector)]);
	
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		NSString *term = [terms objectAtIndex: i];
		int freq = [[freqs objectAtIndex: i] intValue];
		UKTrue([[TestDocHelper FIELD_2_TEXT] rangeOfString: term].location != NSNotFound);
		UKIntsEqual([[[TestDocHelper FIELD_2_FREQS] objectAtIndex: i] intValue], freq);
	}

	//NSLog(@"---------------------begin TestMerge-------------------");

	[TestSegmentReader checkNorms: mergedReader];
	
	//NSLog(@"---------------------end TestMerge-------------------");
}

@end
