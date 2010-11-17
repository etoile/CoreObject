#include "LCDocument.h"
#include "GNUstep.h"
#include <UnitKit/UnitKit.h>

@interface TestDocument: NSObject <UKTest>
@end

@implementation TestDocument

- (void) makeDocumentWithFields: (LCDocument *) doc 
{
	[doc addField: [[LCField alloc] initWithName: @"keyword" 
										   string: @"test1"
											store: LCStore_YES
											index: LCIndex_Untokenized]];
	[doc addField: [[LCField alloc] initWithName: @"keyword" 
										   string: @"test2"
											store: LCStore_YES
											index: LCIndex_Untokenized]];
	[doc addField: [[LCField alloc] initWithName: @"text" 
										   string: @"test1"
											store: LCStore_YES
											index: LCIndex_Tokenized]];
	[doc addField: [[LCField alloc] initWithName: @"text" 
										   string: @"test2"
											store: LCStore_YES
											index: LCIndex_Tokenized]];
	[doc addField: [[LCField alloc] initWithName: @"unindexed" 
										   string: @"test1"
											store: LCStore_YES
											index: LCIndex_NO]];
	[doc addField: [[LCField alloc] initWithName: @"unindexed" 
										   string: @"test2"
											store: LCStore_YES
											index: LCIndex_NO]];
	[doc addField: [[LCField alloc] initWithName: @"unstored" 
										   string: @"test1"
											store: LCStore_YES
											index: LCIndex_Tokenized]];
	[doc addField: [[LCField alloc] initWithName: @"unstored" 
										   string: @"test2"
											store: LCStore_YES
											index: LCIndex_Tokenized]];
}

- (void) doAssertFromIndex: (BOOL) fromIndex : (LCDocument *) doc
{
	NSArray *keywordFieldValues = [doc allStringsForField: @"keyword"];
	NSArray *textFieldValues = [doc allStringsForField: @"text"];
	NSArray *unindexedFieldValues = [doc allStringsForField: @"unindexed"];
	NSArray *unstoredFieldValues = [doc allStringsForField: @"unstored"];
	
	UKIntsEqual(2, [keywordFieldValues count]);
	UKIntsEqual(2, [textFieldValues count]);
	UKIntsEqual(2, [unindexedFieldValues count]);
	// this test cannot work for documents retrieved from the index
	// since unstored fields will obviously not be returned
	if (! fromIndex)
    {
		UKIntsEqual(2, [unstoredFieldValues count]);
    }
	
	UKStringsEqual(@"test1", [keywordFieldValues objectAtIndex: 0]);
	UKStringsEqual(@"test2", [keywordFieldValues objectAtIndex: 1]);
	UKStringsEqual(@"test1", [textFieldValues objectAtIndex: 0]);
	UKStringsEqual(@"test2", [textFieldValues objectAtIndex: 1]);
	UKStringsEqual(@"test1", [unindexedFieldValues objectAtIndex: 0]);
	UKStringsEqual(@"test2", [unindexedFieldValues objectAtIndex: 1]);
	// this test cannot work for documents retrieved from the index
	// since unstored fields will obviously not be returned
	if (! fromIndex)
    {
		UKStringsEqual(@"test1", [unstoredFieldValues objectAtIndex: 0]);
		UKStringsEqual(@"test2", [unstoredFieldValues objectAtIndex: 1]);
    }
}

- (void) testRemoveForNewDocument
{
	LCDocument *doc = [[LCDocument alloc] init];
	[self makeDocumentWithFields: doc];
	UKIntsEqual(8, [[doc fields] count]);
	[doc removeFields: @"keyword"];
	UKIntsEqual(6, [[doc fields] count]);
	[doc removeFields: @"doexnotexists"];
	[doc removeFields: @"keyword"];
	UKIntsEqual(6, [[doc fields] count]);
	[doc removeField: @"text"];
	UKIntsEqual(5, [[doc fields] count]);
	[doc removeField: @"text"];
	UKIntsEqual(4, [[doc fields] count]);
	[doc removeField: @"text"];
	UKIntsEqual(4, [[doc fields] count]);
	[doc removeField: @"doesnotexists"];
	UKIntsEqual(4, [[doc fields] count]);
	[doc removeFields: @"unindexed"];
	UKIntsEqual(2, [[doc fields] count]);
	[doc removeFields: @"unstored"];
	UKIntsEqual(0, [[doc fields] count]);
	[doc removeField: @"doesnotexists"];
	UKIntsEqual(0, [[doc fields] count]);
}

- (void) testGetValuesForNewDocument
{
	LCDocument *doc = [[LCDocument alloc] init];
	[self makeDocumentWithFields: doc];
	[self doAssertFromIndex: NO: doc];
}

- (void) testBinaryField
{
	NSString *binaryVal = @"this text will be stored as a byte array in the index";
	NSString *binaryVal2 = @"this text will be also stored as a byte array in the index";
	
	LCField *stringFld = [[LCField alloc] initWithName: @"string"
												string: binaryVal
												 store: LCStore_YES
												 index: LCIndex_NO];
	LCField *binaryFld = [[LCField alloc] initWithName: @"binary"
												 data: [binaryVal dataUsingEncoding: [NSString defaultCStringEncoding]]
												 store: LCStore_YES];
	LCField *binaryFld2 = [[LCField alloc] initWithName: @"binary"
												  data: [binaryVal2 dataUsingEncoding: [NSString defaultCStringEncoding]]
												  store: LCStore_YES];

	LCDocument *doc = [[LCDocument alloc] init];
	
	[doc addField: stringFld];
	[doc addField: binaryFld];
	
	UKIntsEqual(2, [[doc fields] count]);
	
	UKTrue([binaryFld isData]);
	UKTrue([binaryFld isStored]);
	UKFalse([binaryFld isIndexed]);
	UKFalse([binaryFld isTokenized]);
	
	NSString *binaryTest = [[NSString alloc] initWithData: [doc dataForField: @"binary"] 
												 encoding: [NSString defaultCStringEncoding]];
	UKStringsEqual(binaryTest, binaryVal);
	
	NSString *stringTest = [doc stringForField: @"string"];
	UKStringsEqual(binaryTest, stringTest);
	
	[doc addField: binaryFld2];
	UKIntsEqual(3, [[doc fields] count]);
	
	NSArray *binaryTests = [doc allDataForField: @"binary"];
	UKIntsEqual(2, [binaryTests count]);
	
	binaryTest = [[NSString alloc] initWithData: [binaryTests objectAtIndex: 0] 
									   encoding: [NSString defaultCStringEncoding]];
	NSString *binaryTest2 = [[NSString alloc] initWithData: [binaryTests objectAtIndex: 1] 
												  encoding: [NSString defaultCStringEncoding]];
    
	UKFalse([binaryTest isEqualToString: binaryTest2]);
	UKStringsEqual(binaryTest, binaryVal);
	UKStringsEqual(binaryTest2, binaryVal2);
	
	[doc removeField: @"string"];
	UKIntsEqual(2, [[doc fields] count]);
	
	[doc removeFields: @"binary"];
	UKIntsEqual(0, [[doc fields] count]);
}

#if 0
public void testConstructorExceptions()
{
	new Field("name", "value", Field.Store.YES, Field.Index.NO);  // okay
	new Field("name", "value", Field.Store.NO, Field.Index.UN_TOKENIZED);  // okay
	try {
		new Field("name", "value", Field.Store.NO, Field.Index.NO);
		fail();
	} catch(IllegalArgumentException e) {
		// expected exception
	}
	new Field("name", "value", Field.Store.YES, Field.Index.NO, Field.TermVector.NO); // okay
	try {
		new Field("name", "value", Field.Store.YES, Field.Index.NO, Field.TermVector.YES);
		fail();
	} catch(IllegalArgumentException e) {
		// expected exception
	}
}
#endif
//

#if 0
public void testGetValuesForIndexedDocument() throws Exception
{
	RAMDirectory dir = new RAMDirectory();
	IndexWriter writer = new IndexWriter(dir, new StandardAnalyzer(), true);
	writer.addDocument(makeDocumentWithFields());
	writer.close();
	
	Searcher searcher = new IndexSearcher(dir);
	
	// search for something that does exists
	Query query = new TermQuery(new Term("keyword", "test1"));
	
	// ensure that queries return expected results without DateFilter first
	Hits hits = searcher.search(query);
	assertEquals(1, hits.length());
	
	try
	{
		doAssert(hits.doc(0), true);
	}
	catch (Exception e)
	{
		e.printStackTrace(System.err);
		System.err.print("\n");
	}
	finally
	{
		searcher.close();
	}
}

#endif

@end
