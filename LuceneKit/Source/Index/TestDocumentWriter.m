#include "LCDocumentWriter.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>
#include "LCRAMDirectory.h"
#include "LCWhitespaceAnalyzer.h"
#include "LCSegmentReader.h"
#include "LCSegmentInfo.h"
#include "TestDocHelper.h"
#include "LCField.h"
#include "LCWhitespaceTokenizer.h"

@interface TestDocumentWriter: NSObject <UKTest>
@end

@interface TestDocAnalyzer: LCAnalyzer
@end

@implementation TestDocumentWriter
- (void) testDocumentWriter
{
	LCRAMDirectory *dir = [[LCRAMDirectory alloc] init];
	LCDocument *testDoc = [[LCDocument alloc] init];
	[TestDocHelper setupDoc: testDoc];
	UKNotNil(dir);
	LCAnalyzer *analyzer = [[LCWhitespaceAnalyzer alloc] init];
	LCSimilarity *similarity= [LCSimilarity defaultSimilarity];
	LCDocumentWriter *writer = [[LCDocumentWriter alloc] initWithDirectory: dir
																  analyzer: analyzer similarity: similarity maxFieldLength: 50];
	UKNotNil(writer);
	NSString *segName = @"test";
	[writer addDocument: segName document: testDoc];
	
	//After adding the document, we should be able to read it back in
	LCSegmentReader *reader = [LCSegmentReader segmentReaderWithInfo: [[LCSegmentInfo alloc] initWithName: segName numberOfDocuments: 1 directory: dir]];
	UKNotNil(reader);
	LCDocument *doc = [reader document: 0];
	UKNotNil(doc);
	
	NSArray *fields = [doc fields: @"textField2"];
	UKNotNil(fields);
	UKIntsEqual(1, [fields count]);
	UKStringsEqual([TestDocHelper FIELD_2_TEXT], [[fields objectAtIndex: 0] string]);
	UKTrue([[fields objectAtIndex: 0] isTermVectorStored]);
	
	fields = [doc fields: @"textField1"];
	UKNotNil(fields);
	UKIntsEqual(1, [fields count]);
	UKStringsEqual([TestDocHelper FIELD_1_TEXT], [[fields objectAtIndex: 0] string]);
	UKFalse([[fields objectAtIndex: 0] isTermVectorStored]);
	
	fields = [doc fields: @"keyField"];
	UKNotNil(fields);
	UKIntsEqual(1, [fields count]);
	UKStringsEqual([TestDocHelper KEYWORD_TEXT], [[fields objectAtIndex: 0] string]);

	fields = [doc fields: [TestDocHelper NO_NORMS_KEY]];
	UKNotNil(fields);
	UKIntsEqual(1, [fields count]);
	UKStringsEqual([TestDocHelper NO_NORMS_TEXT], [[fields objectAtIndex: 0] string]);

	fields = [doc fields: [TestDocHelper TEXT_FIELD_3_KEY]];
	UKNotNil(fields);
	UKIntsEqual(1, [fields count]);
	UKStringsEqual([TestDocHelper FIELD_3_TEXT], [[fields objectAtIndex: 0] string]);

	// test that the norm file is not present if omitNorms is true
	int i;
	for(i = 0; i < [[reader fieldInfos] size]; i++) {
		LCFieldInfo *fi = [[reader fieldInfos] fieldInfoWithNumber: i];
		if ([fi isIndexed]) {
			NSString *filename = [NSString stringWithFormat: @"%@.f%d", segName, i];
			BOOL fileExist = [dir fileExists: filename];
			UKTrue([fi omitNorms] == !fileExist);
		}
	}
			

}

- (void) testPositionIncrementGap
{
	LCRAMDirectory *dir = [[LCRAMDirectory alloc] init];
	LCAnalyzer *analyzer = [[TestDocAnalyzer alloc] init];
	LCSimilarity *similarity= [LCSimilarity defaultSimilarity];
	LCDocumentWriter *writer = [[LCDocumentWriter alloc] initWithDirectory: dir
																  analyzer: analyzer similarity: similarity maxFieldLength: 50];
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"repeated"
					string: @"repeated one"
					store: LCStore_YES
					index: LCIndex_Tokenized];
	[doc addField: field];
	field = [[LCField alloc] initWithName: @"repeated"
					string: @"repeated two"
					store: LCStore_YES
					index: LCIndex_Tokenized];
	[doc addField: field];

	NSString *segName = @"test";
	[writer addDocument: segName document: doc];

	LCSegmentReader *reader = [LCSegmentReader segmentReaderWithInfo: [[LCSegmentInfo alloc] initWithName: segName numberOfDocuments: 1 directory: dir]];
	LCTerm *t = [[LCTerm alloc] initWithField: @"repeated" text: @"repeated"];
	id <LCTermPositions> termPositions = [reader termPositionsWithTerm: t];
	UKTrue([termPositions hasNextDocument]);
	int freq = [termPositions frequency];
	UKIntsEqual(2, freq);
 	UKIntsEqual(0, [termPositions nextPosition]);
 	UKIntsEqual(502, [termPositions nextPosition]);
}
#if 0
  	     SegmentReader reader = SegmentReader.get(new SegmentInfo(segName, 1, dir));
  	 
  	     TermPositions termPositions = reader.termPositions(new Term("repeated", "repeated"));
  	     assertTrue(termPositions.next());
  	     int freq = termPositions.freq();
  	     assertEquals(2, freq);
  	     assertEquals(0, termPositions.nextPosition());
  	     assertEquals(502, termPositions.nextPosition());
   } 	   }
#endif

@end

@implementation TestDocAnalyzer
- (LCTokenStream *) tokenStreamWithField: (NSString *) name
                                  reader: (id <LCReader>) reader
{
	return AUTORELEASE([[LCWhitespaceTokenizer alloc] initWithReader: reader]);
}

- (int) positionIncrementGap: (NSString *) fieldName
{
	return 500;
}

@end
