#include "TestDocHelper.h"
#include "LCDocument.h"
#include "LCField.h"
#include "LCRAMDirectory.h"
#include "LCSegmentReader.h"
#include "LCSegmentInfo.h"
#include "LCSegmentTermDocs.h"
#include "LCTerm.h"
#include "LCIndexWriter.h"
#include "LCIndexReader.h"
#include "LCTermDocs.h"
#include "LCWhitespaceAnalyzer.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "LCDirectory.h"
#include "GNUstep.h"

@interface TestSegmentTermDocs: NSObject <UKTest>
{
	LCDocument *testDoc;
	id <LCDirectory> dir;
}
@end

@implementation TestSegmentTermDocs

- (id) init
{
	self = [super init];
	testDoc = [[LCDocument alloc] init];
	dir = [[LCRAMDirectory alloc] init];
	[TestDocHelper setupDoc: testDoc];
	[TestDocHelper writeDirectory: dir doc: testDoc];
	return self;
}

- (void) testTermDocs
{
	UKNotNil(dir);
	
	//After adding the document, we should be able to read it back in
	LCSegmentInfo *si = [[LCSegmentInfo alloc] initWithName: @"test" numberOfDocuments: 1 directory: dir];
	LCSegmentReader *reader = [LCSegmentReader segmentReaderWithInfo: si];
	UKNotNil(reader);
	LCSegmentTermDocuments *segTermDocs = [[LCSegmentTermDocuments alloc] initWithSegmentReader: reader];
	UKNotNil(segTermDocs);
	LCTerm *t = [[LCTerm alloc] initWithField: [TestDocHelper TEXT_FIELD_2_KEY]
										 text: @"field"];
	[segTermDocs seekTerm: t];
	if ([segTermDocs hasNextDocument] == YES)
	{
        long docId = [segTermDocs document];
		UKIntsEqual(docId, 0);
        long freq = [segTermDocs frequency];
		UKIntsEqual(freq, 3);
	}
	[reader close];
}  

- (void) testBadSeek
{
	LCSegmentInfo *si = [[LCSegmentInfo alloc] initWithName: @"test" numberOfDocuments: 3 directory: dir];
	LCSegmentReader *reader = [LCSegmentReader segmentReaderWithInfo: si];
	UKNotNil(reader);
	LCSegmentTermDocuments *segTermDocs = [[LCSegmentTermDocuments alloc] initWithSegmentReader: reader];
	UKNotNil(segTermDocs);
	LCTerm *t = [[LCTerm alloc] initWithField: @"testField2" text: @"bad"];
	UKFalse([segTermDocs hasNextDocument]);
	[reader close];
	
	si = [[LCSegmentInfo alloc] initWithName: @"test" numberOfDocuments: 3 directory: dir];
	reader = [LCSegmentReader segmentReaderWithInfo: si];
	UKNotNil(reader);
	segTermDocs = [[LCSegmentTermDocuments alloc] initWithSegmentReader: reader];
	UKNotNil(segTermDocs);
	t = [[LCTerm alloc] initWithField: @"junk" text: @"bad"];
	UKFalse([segTermDocs hasNextDocument]);
	[reader close];
}

- (void) addDoc: (LCIndexWriter *) writer value: (NSString *) value
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"content"
											string: value
											 store: LCStore_NO
											 index: LCIndex_Tokenized];
	[doc addField: field];
	RELEASE(field);
	[writer addDocument: doc];
	RELEASE(doc);
}

- (void) testSkipTo
{
	id <LCDirectory> d = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: d
															analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	
	LCTerm *ta = [[LCTerm alloc] initWithField: @"content" text: @"aaa"];
	int i;
	for(i = 0; i < 10; i++)
		[self addDoc: writer value: @"aaa aaa aaa aaa"];
	
	LCTerm *tb = [[LCTerm alloc] initWithField: @"content" text: @"bbb"];
	for(i = 0; i < 16; i++)
		[self addDoc: writer value: @"bbb bbb bbb bbb"];
	
	LCTerm *tc = [[LCTerm alloc] initWithField: @"content" text: @"ccc"];
	for(i = 0; i < 50; i++)
		[self addDoc: writer value: @"ccc ccc ccc ccc"];
	
	// assure that we deal with a single segment  
	[writer optimize];
	[writer close];
	
	//NSLog(@"===== TestSkipTo ======");
	LCIndexReader *reader = [LCIndexReader openDirectory: d];
	id <LCTermDocuments> tdocs = [reader termDocuments];
	
	// without optimization (assumption skipInterval == 16)
	
	// with next
	[tdocs seekTerm: ta];
	UKTrue([tdocs hasNextDocument]);
	UKIntsEqual(0, [tdocs document]);
	UKIntsEqual(4, [tdocs frequency]);
	UKTrue([tdocs hasNextDocument]);
	UKIntsEqual(1, [tdocs document]);
	UKIntsEqual(4, [tdocs frequency]);
	UKTrue([tdocs skipTo: 0]);
	UKIntsEqual(2, [tdocs document]);
	UKTrue([tdocs skipTo: 4]);
	UKIntsEqual(4, [tdocs document]);
	UKTrue([tdocs skipTo: 9]);
	UKIntsEqual(9, [tdocs document]);
	UKFalse([tdocs skipTo: 10]);
	
	// without next
	[tdocs seekTerm: ta];
	UKTrue([tdocs skipTo: 0]);
	UKIntsEqual(0, [tdocs document]);
	UKTrue([tdocs skipTo: 4]);
	UKIntsEqual(4, [tdocs document]);
	UKTrue([tdocs skipTo: 9]);
	UKIntsEqual(9, [tdocs document]);
	UKFalse([tdocs skipTo: 10]);
	
	// exactly skipInterval documents and therefore with optimization
	
	// with next
	[tdocs seekTerm: tb];
	UKTrue([tdocs hasNextDocument]);
	UKIntsEqual(10, [tdocs document]);
	UKIntsEqual(4, [tdocs frequency]);
	UKTrue([tdocs hasNextDocument]);
	UKIntsEqual(11, [tdocs document]);
	UKIntsEqual(4, [tdocs frequency]);
	UKTrue([tdocs skipTo: 5]);
	UKIntsEqual(12, [tdocs document]);
	UKTrue([tdocs skipTo: 15]);
	UKIntsEqual(15, [tdocs document]);
	UKTrue([tdocs skipTo: 24]);
	UKIntsEqual(24, [tdocs document]);
	UKTrue([tdocs skipTo: 25]);
	UKIntsEqual(25, [tdocs document]);
	UKFalse([tdocs skipTo: 26]);
	
	// without next
	[tdocs seekTerm: tb];
	UKTrue([tdocs skipTo: 5]);
	UKIntsEqual(10, [tdocs document]);
	UKTrue([tdocs skipTo: 15]);
	UKIntsEqual(15, [tdocs document]);
	UKTrue([tdocs skipTo: 24]);
	UKIntsEqual(24, [tdocs document]);
	UKTrue([tdocs skipTo: 25]);
	UKIntsEqual(25, [tdocs document]);
	UKFalse([tdocs skipTo: 26]);
	
	// much more than skipInterval documents and therefore with optimization
	
	// with next
	[tdocs seekTerm: tc];
	UKTrue([tdocs hasNextDocument]);
	UKIntsEqual(26, [tdocs document]);
	UKIntsEqual(4, [tdocs frequency]);
	UKTrue([tdocs hasNextDocument]);
	UKIntsEqual(27, [tdocs document]);
	UKIntsEqual(4, [tdocs frequency]);
	UKTrue([tdocs skipTo: 5]);
	UKIntsEqual(28, [tdocs document]);
	UKTrue([tdocs skipTo: 40]);
	UKIntsEqual(40, [tdocs document]);
	UKTrue([tdocs skipTo: 57]);
	UKIntsEqual(57, [tdocs document]);
	UKTrue([tdocs skipTo: 74]);
	UKIntsEqual(74, [tdocs document]);
	UKTrue([tdocs skipTo: 75]);
	UKIntsEqual(75, [tdocs document]);
	UKFalse([tdocs skipTo: 76]);
	
	//without next
	[tdocs seekTerm: tc];
	UKTrue([tdocs skipTo: 5]);
	UKIntsEqual(26, [tdocs document]);
	UKTrue([tdocs skipTo: 40]);
	UKIntsEqual(40, [tdocs document]);
	UKTrue([tdocs skipTo: 57]);
	UKIntsEqual(57, [tdocs document]);
	UKTrue([tdocs skipTo: 74]);
	UKIntsEqual(74, [tdocs document]);
	UKTrue([tdocs skipTo: 75]);
	UKIntsEqual(75, [tdocs document]);
	UKFalse([tdocs skipTo: 76]);
	
	[tdocs close];
	[reader close];
	[dir close];
	//  NSLog(@"===== TestSkipTo ====== done");
}
@end
