#include "LCRAMDirectory.h"
#include "LCFieldInfos.h"
#include "LCTermVectorsWriter.h"
#include "LCTermVectorsReader.h"
#include "LCWhitespaceAnalyzer.h"
#include "LCIndexWriter.h"
#include "LCField.h"
#include "LCDocument.h"
#include "GNUstep.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>

@interface TestTermVectorsWriter: NSObject <UKTest>
{
	NSArray *testTerms;
	NSArray *testFields;
	NSMutableArray *positions;
	LCRAMDirectory *dir;
	NSString *seg;
	LCFieldInfos *fieldInfos;
}

@end

@implementation TestTermVectorsWriter

- (id) init
{
	self = [super init];
	testTerms = [NSArray arrayWithObjects: @"this", @"is", @"a", @"test", nil];
	testFields = [NSArray arrayWithObjects: @"f1", @"f2", @"f3", nil];
	positions = [[NSMutableArray alloc] init];
	dir = [[LCRAMDirectory alloc] init];
	seg = @"testSegment";
	fieldInfos = [[LCFieldInfos alloc] init];
	
	int i, j;
	for (i = 0; i < [testFields count]; i++)
	{
		[fieldInfos addName: [testFields objectAtIndex: i]
				  isIndexed: YES
		 isTermVectorStored: YES];
	}
	for (i = 0; i < [testTerms count]; i++)
	{
		NSMutableArray *a = [[NSMutableArray alloc] init];
		for (j = 0; j < 5; j++)
			[a addObject: [NSNumber numberWithInt: j*10]];
		[positions addObject: a];
		RELEASE(a);
	}
	
	return self;
}

- (void) testBasic
{
	UKNotNil(dir);
	UKNotNil(positions);
}

/* Comment out by lucene, not LuceneKit */
/*public void testWriteNoPositions() {
try {
	TermVectorsWriter writer = new TermVectorsWriter(dir, seg, 50);
	writer.openDocument();
	assertTrue(writer.isDocumentOpen() == true);
	writer.openField(0);
	assertTrue(writer.isFieldOpen() == true);
	for (int i = 0; i < testTerms.length; i++) {
        writer.addTerm(testTerms[i], i);
	}
	writer.closeField();
	
	writer.closeDocument();
	writer.close();
	assertTrue(writer.isDocumentOpen() == false);
	//Check to see the files were created
	assertTrue(dir.fileExists(seg + TermVectorsWriter.TVD_EXTENSION));
	assertTrue(dir.fileExists(seg + TermVectorsWriter.TVX_EXTENSION));
	//Now read it back in
	TermVectorsReader reader = new TermVectorsReader(dir, seg);
	assertTrue(reader != null);
	checkTermVector(reader, 0, 0);
} catch (IOException e) {
	e.printStackTrace();
	assertTrue(false);
}
}  */  

- (void) writeField: (LCTermVectorsWriter *) writer : (NSString *) f
{
	[writer openField: f];
	UKTrue([writer isFieldOpen]);
	int i;
	for (i = 0; i < [testTerms count]; i++)
	{
		[writer addTerm: [testTerms objectAtIndex: i] freq: i];
	}
	[writer closeField];
}

- (void) writeDocument: (LCTermVectorsWriter *) writer : (int) numFields
{
	[writer openDocument];
	UKTrue([writer isDocumentOpen]);
	int j;
	for (j = 0; j < numFields; j++)
	{
		[self writeField: writer : [testFields objectAtIndex: j]];
	}
	[writer closeDocument];
	UKFalse([writer isDocumentOpen]);
}

- (void) checkTermVector: (LCTermVectorsReader *) reader : (int) docNum : (NSString *) field
{
	id <LCTermFrequencyVector> vector = [reader termFrequencyVector: docNum field: field];
	UKNotNil(vector);
	NSArray *terms = [vector allTerms];
	UKNotNil(terms);
	UKIntsEqual([terms count], [testTerms count]);
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		NSString *term = [terms objectAtIndex: i];
		UKTrue([term isEqualToString: [testTerms objectAtIndex: i]]);
	}
}

- (void) testWriter
{
	LCTermVectorsWriter *writer = [[LCTermVectorsWriter alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	[writer openDocument];
	UKTrue([writer isDocumentOpen]);
	[self writeField: writer : [testFields objectAtIndex: 0]];
	[writer closeDocument];
	[writer close];
	UKFalse([writer isDocumentOpen]);
	//Check to see the files were created
	NSString *file = [seg stringByAppendingPathExtension: TVD_EXTENSION];
	UKTrue([dir fileExists: file]);
	file = [seg stringByAppendingPathExtension: TVX_EXTENSION];
	UKTrue([dir fileExists: file]);
	//Now read it back in
	LCTermVectorsReader *reader = [[LCTermVectorsReader alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	UKNotNil(reader);
	[self checkTermVector: reader : 0 : [testFields objectAtIndex: 0]];
}

/**
* Test one document, multiple fields
 */
- (void) testMultipleFields
{
	LCTermVectorsWriter *writer = [[LCTermVectorsWriter alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	[self writeDocument: writer : [testFields count]];
	[writer close];
	UKFalse([writer isDocumentOpen]);
	//Check to see the files were created
	NSString *file = [seg stringByAppendingPathExtension: TVD_EXTENSION];
	UKTrue([dir fileExists: file]);
	file = [seg stringByAppendingPathExtension: TVX_EXTENSION];
	UKTrue([dir fileExists: file]);
	//Now read it back in
	LCTermVectorsReader *reader = [[LCTermVectorsReader alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	UKNotNil(reader);
	
	int j;
	for (j = 0; j < [testFields count]; j++)
	{
		[self checkTermVector: reader : 0 : [testFields objectAtIndex: j]];
	}
}

- (void) testMultipleDocument
{
	LCTermVectorsWriter *writer = [[LCTermVectorsWriter alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	UKNotNil(writer);
	int i;
	for (i = 0; i < 10; i++) {
		[self writeDocument: writer : [testFields count]];
	}
	[writer close];
	
	LCTermVectorsReader *reader = [[LCTermVectorsReader alloc] initWithDirectory: dir segment: seg fieldInfos: fieldInfos];
	for (i = 0; i < 10; i++) {
		UKNotNil(reader);
		[self checkTermVector: reader : 5 : [testFields objectAtIndex: 0]];
		[self checkTermVector: reader : 2 : [testFields objectAtIndex: 2]];
	}
}

/**
* Test that no NullPointerException will be raised,
 * when adding one document with a single, empty field
 * and term vectors enabled.
 *
 */
- (void) testBadSegment
{
	LCIndexWriter *ir = [[LCIndexWriter alloc] initWithDirectory: dir analyzer: [[LCWhitespaceAnalyzer alloc] init] create: YES];
	LCField *field = [[LCField alloc] initWithName: @"tvtest" string: @"" store: LCStore_NO index: LCIndex_Tokenized];
	LCDocument *document = [[LCDocument alloc] init];
	[document addField: field];
	[ir addDocument: document];
#if 0 // FIXME
	[ir close];
#endif
}

@end
