#include "TestDocHelper.h"
#include "TestSegmentReader.h"
#include "LCDocument.h"
#include "LCRAMDirectory.h"
#include "LCSegmentInfos.h"
#include "LCSegmentInfo.h"
#include "LCSegmentReader.h"
#include "LCMultiReader.h"
#include "LCTermFreqVector.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "LCDirectory.h"

@interface TestMultiReader: NSObject <UKTest>
{
	id <LCDirectory> dir;
	LCDocument *doc1;
	LCDocument *doc2;
	LCSegmentReader *reader1;
	LCSegmentReader *reader2;
	NSMutableArray *readers;
	LCSegmentInfos *sis;
}

@end

@implementation TestMultiReader

- (id) init
{
	self = [super init];
	dir = [[LCRAMDirectory alloc] init];
	doc1 = [[LCDocument alloc] init];;
	doc2 = [[LCDocument alloc] init];;
	readers = [[NSMutableArray alloc] init];
	sis = [[LCSegmentInfos alloc] init];
	
	[TestDocHelper setupDoc: doc1];
	[TestDocHelper setupDoc: doc2];
	[TestDocHelper writeDirectory: dir segment: @"seg-1" doc: doc1];
	[TestDocHelper writeDirectory: dir segment: @"seg-2" doc: doc2];
    
	[sis writeToDirectory: dir];
	LCSegmentInfo *si = [[LCSegmentInfo alloc] initWithName: @"seg-1"
										  numberOfDocuments: 1 directory: dir];
	reader1 = [LCSegmentReader segmentReaderWithInfo: si];
	si = [[LCSegmentInfo alloc] initWithName: @"seg-2"
						   numberOfDocuments: 1 directory: dir];
	reader2 = [LCSegmentReader segmentReaderWithInfo: si];
	[readers addObject: reader1];
	[readers addObject: reader2];
	return self;
}

- (void) test
{
	UKNotNil(dir);
	UKNotNil(reader1);
	UKNotNil(reader2);
	UKNotNil(sis);
}    

- (void) testDocument
{
	[sis readFromDirectory: dir];
	LCMultiReader *reader = [[LCMultiReader alloc] initWithDirectory: dir
														segmentInfos: sis
															   close: NO
															 readers: readers];
	UKNotNil(reader);
	LCDocument *newDoc1 = [reader document: 0];
	UKNotNil(newDoc1);
	UKIntsEqual([TestDocHelper numFields: newDoc1], [TestDocHelper numFields: doc1]-[[TestDocHelper unstored] count]);
	LCDocument *newDoc2 = [reader document: 1];
	UKNotNil(newDoc2);
	UKIntsEqual([TestDocHelper numFields: newDoc2], [TestDocHelper numFields: doc2]-[[TestDocHelper unstored] count]);
	id <LCTermFrequencyVector> vector = [reader termFrequencyVector: 0 field: [TestDocHelper TEXT_FIELD_2_KEY]];
	UKNotNil(vector);
//NSLog(@"LCMultiReader");
	[TestSegmentReader checkNorms: reader];
//NSLog(@"LCMultiReader ===");
}

- (void) testUndeleteAll
{
	[sis readFromDirectory: dir];
	LCMultiReader *reader = [[LCMultiReader alloc] initWithDirectory: dir
														segmentInfos: sis
															   close: NO
															 readers: readers];
	UKNotNil(reader);
	UKIntsEqual(2, [reader numberOfDocuments]);
	[reader deleteDocument: 0];
	UKIntsEqual(1, [reader numberOfDocuments]);
	[reader undeleteAll];
	UKIntsEqual(2, [reader numberOfDocuments]);
}

- (void) testTermVectors 
{
	LCMultiReader *reader = [[LCMultiReader alloc] initWithDirectory: dir
														segmentInfos: sis
															   close: NO
															 readers: readers];
	UKNotNil(reader);
}

@end
