#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "LCRAMDirectory.h"
#include "LCFSDirectory.h"
#include "LCIndexWriter.h"
#include "LCIndexReader.h"
#include "LCTerm.h"
#include "LCDocument.h"
#include "LCField.h"
#include "LCWhitespaceAnalyzer.h"
#include "GNUstep.h"

@interface TestIndexReader: NSObject <UKTest>
@end

@implementation TestIndexReader

- (void) testEmpty
{
  LCRAMDirectory *store = [[LCRAMDirectory alloc] init];
//  LCFSDirectory *store = [[LCFSDirectory alloc] initWithPath: @"/tmp/yjchen/unique" create: YES];
  LCAnalyzer *analyzer = [[LCWhitespaceAnalyzer alloc] init];
  LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: store
				analyzer: analyzer
				create: YES];
  [writer close];

  LCIndexReader *reader = [LCIndexReader openDirectory: store];
  UKIntsEqual(0, [reader numberOfDocuments]);
  LCTermEnumerator *te = [reader termEnumerator];
  while ([te hasNextTerm])
  {
    [te term];
  }
  [te close];

  [reader close];
}

- (void) _addDocumentWithFields: (LCIndexWriter *) writer
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"keyword"
											string: @"test1"
											 store: LCStore_YES
											 index: LCIndex_Untokenized];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"text"
								   string: @"test1"
									store: LCStore_YES
									index: LCIndex_Tokenized];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"unindexed"
								   string: @"test1"
									store: LCStore_YES
									index: LCIndex_NO];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"unstored"
								   string: @"test1"
									store: LCStore_NO
									index: LCIndex_Tokenized];
	[doc addField: field];
	RELEASE(field);
	[writer addDocument: doc];
	RELEASE(doc);
}

- (void) _addDocWithDiffFields: (LCIndexWriter *) writer
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"keyword2"
											string: @"test1"
											 store: LCStore_YES
											 index: LCIndex_Untokenized];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"text2"
								   string: @"test1"
									store: LCStore_YES
									index: LCIndex_Tokenized];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"unindexed2"
								   string: @"test1"
									store: LCStore_YES
									index: LCIndex_NO];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"unstored2"
								   string: @"test1"
									store: LCStore_NO
									index: LCIndex_Tokenized];
	[doc addField: field];
	RELEASE(field);
	[writer addDocument: doc];
	RELEASE(doc);
}

- (void) _addDocWithTVFields: (LCIndexWriter *) writer
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"tvnot"
											string: @"tvnot"
											 store: LCStore_YES
											 index: LCIndex_Tokenized
										termVector: LCTermVector_NO];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"termvector"
								   string: @"termvector"
									store: LCStore_YES
									index: LCIndex_Tokenized
							   termVector: LCTermVector_YES];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"tvoffset"
								   string: @"tvoffset"
									store: LCStore_YES
									index: LCIndex_Tokenized
							   termVector: LCTermVector_WithOffsets];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"tvposition"
								   string: @"tvposition"
									store: LCStore_YES
									index: LCIndex_Tokenized
							   termVector: LCTermVector_WithPositions];
	[doc addField: field];
	RELEASE(field);
	field = [[LCField alloc] initWithName: @"tvpositionoffset"
								   string: @"tvpositionoffset"
									store: LCStore_YES
									index: LCIndex_Tokenized
							   termVector: LCTermVector_WithPositionsAndOffsets];
	[doc addField: field];
	RELEASE(field);
	[writer addDocument: doc];
	RELEASE(doc);
}

- (void) _addDoc: (LCIndexWriter *) writer value: (NSString *) value
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
/**
* Tests the IndexReader.getFieldNames implementation
 * @throws Exception on error
 */
- (void) testGetFieldNames
{
	LCRAMDirectory *d = [[LCRAMDirectory alloc] init];
	// set up writer
	// FIXME: original test using StandardAnalyzer
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: d
															analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	[self _addDocumentWithFields: writer];
	[writer close];
	// set up reader
	LCIndexReader *reader = [LCIndexReader openDirectory: d];
	NSArray *fieldNames = [reader fieldNames: LCFieldOption_ALL];
	UKTrue([fieldNames containsObject: @"keyword"]);
	UKTrue([fieldNames containsObject: @"text"]);
	UKTrue([fieldNames containsObject: @"unindexed"]);
	UKTrue([fieldNames containsObject: @"unstored"]);
	[reader close];
	
	// add more documents
	writer = [[LCIndexWriter alloc] initWithDirectory: d
											 analyzer: [[LCWhitespaceAnalyzer alloc] init]
											   create: NO];
	// want to get some more segments here
	int i;
	for (i = 0; i < 5*[writer mergeFactor]; i++)
	{
		[self _addDocumentWithFields: writer];
	}
	// new fields are in some different segments (we hope)
	for (i = 0; i < 5*[writer mergeFactor]; i++)
	{
		[self _addDocWithDiffFields: writer];
	}
	// new termvector fields
	for (i = 0; i < 5*[writer mergeFactor]; i++)
	{
		[self _addDocWithTVFields: writer];
	}
	
	[writer close];
	[d close];
	
	DESTROY(writer);
	// verify fields again
	reader = [LCIndexReader openDirectory: d];
	fieldNames = [reader fieldNames: LCFieldOption_ALL];
	UKIntsEqual(13, [fieldNames count]); // the following fields
	UKTrue([fieldNames containsObject: @"keyword"]);
	UKTrue([fieldNames containsObject: @"text"]);
	UKTrue([fieldNames containsObject: @"unindexed"]);
	UKTrue([fieldNames containsObject: @"unstored"]);
	UKTrue([fieldNames containsObject: @"keyword2"]);
	UKTrue([fieldNames containsObject: @"text2"]);
	UKTrue([fieldNames containsObject: @"unindexed2"]);
	UKTrue([fieldNames containsObject: @"unstored2"]);
	UKTrue([fieldNames containsObject: @"tvnot"]);
	UKTrue([fieldNames containsObject: @"termvector"]);
	UKTrue([fieldNames containsObject: @"tvposition"]);
	UKTrue([fieldNames containsObject: @"tvoffset"]);
	UKTrue([fieldNames containsObject: @"tvpositionoffset"]);
	
	// verify that only indexed fields were returned
	fieldNames = [reader fieldNames: LCFieldOption_INDEXED];
	UKIntsEqual(11, [fieldNames count]); // 6 original + the 5 termvector fields 
	UKTrue([fieldNames containsObject: @"keyword"]);
	UKTrue([fieldNames containsObject: @"text"]);
	UKTrue([fieldNames containsObject: @"unstored"]);
	UKTrue([fieldNames containsObject: @"keyword2"]);
	UKTrue([fieldNames containsObject: @"text2"]);
	UKTrue([fieldNames containsObject: @"unstored2"]);
	UKTrue([fieldNames containsObject: @"tvnot"]);
	UKTrue([fieldNames containsObject: @"termvector"]);
	UKTrue([fieldNames containsObject: @"tvposition"]);
	UKTrue([fieldNames containsObject: @"tvoffset"]);
	UKTrue([fieldNames containsObject: @"tvpositionoffset"]);
	
	// verify that only unindexed fields were returned
	fieldNames = [reader fieldNames: LCFieldOption_UNINDEXED];
	UKIntsEqual(2, [fieldNames count]); 
	UKTrue([fieldNames containsObject: @"unindexed"]);
	UKTrue([fieldNames containsObject: @"unindexed2"]);
	
	// verify index term vector fields  
	fieldNames = [reader fieldNames: LCFieldOption_TERMVECTOR];
	UKIntsEqual(1, [fieldNames count]); 
	UKTrue([fieldNames containsObject: @"termvector"]);
	
	fieldNames = [reader fieldNames: LCFieldOption_TERMVECTOR_WITH_POSITION];
	UKIntsEqual(1, [fieldNames count]); 
	UKTrue([fieldNames containsObject: @"tvposition"]);
	
	fieldNames = [reader fieldNames: LCFieldOption_TERMVECTOR_WITH_OFFSET];
	UKIntsEqual(1, [fieldNames count]); 
	UKTrue([fieldNames containsObject: @"tvoffset"]);
	
	fieldNames = [reader fieldNames: LCFieldOption_TERMVECTOR_WITH_POSITION_OFFSET];
	UKIntsEqual(1, [fieldNames count]); 
	UKTrue([fieldNames containsObject: @"tvpositionoffset"]);
	
	DESTROY(d);
}

- (void) _assertTermDocsCount: (NSString *) msg
					   reader: (LCIndexReader *) reader
						 term: (LCTerm *) term
					 expected: (int) expected
{
	id <LCTermDocuments> tdocs = nil;
	tdocs = [reader termDocumentsWithTerm: term];
	UKNotNil(tdocs);
	int count = 0;
	while ([tdocs hasNextDocument])
	{
		count++;
	}
	UKIntsEqual(expected, count);
	[tdocs close];
}

- (void) testBasicDelete
{
	id <LCDirectory> dir = [[LCRAMDirectory alloc] init];
	
	LCIndexWriter *writer = nil;
	LCIndexReader *reader = nil;
	LCTerm *searchTerm = [[LCTerm alloc] initWithField: @"content" text: @"aaa"];
	
	//  add 100 documents with term : aaa
	writer = [[LCIndexWriter alloc] initWithDirectory: dir
											 analyzer: [[LCWhitespaceAnalyzer alloc] init]
											   create: YES];
	int i;
	for (i = 0; i < 100; i++)
	{
		[self _addDoc: writer value: [searchTerm text]];
	}
	[writer close];
	
	// OPEN READER AT THIS POINT - this should fix the view of the
	// index at the point of having 100 "aaa" documents and 0 "bbb"
	reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	[self _assertTermDocsCount: @"first reader"
						reader: reader
						  term: searchTerm
					  expected: 100];
	
	// DELETE DOCUMENTS CONTAINING TERM: aaa
	int deleted = 0;
	reader = [LCIndexReader openDirectory: dir];
	deleted = [reader deleteTerm: searchTerm];
	UKIntsEqual(100, deleted);
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	[self _assertTermDocsCount: @"first reader"
						reader: reader
						  term: searchTerm
					  expected: 0];
	[reader close];
	
	// CREATE A NEW READER and re-test
	reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	[self _assertTermDocsCount: @"first reader"
						reader: reader
						  term: searchTerm
					  expected: 0];
	[reader close];
}

- (void) _deleteRWConflict: (BOOL) optimize
{
	id <LCDirectory> dir = [[LCRAMDirectory alloc] init];
	// Directory dir = getDirectory(true);
	
	LCTerm *searchTerm = [[LCTerm alloc] initWithField: @"content" text: @"aaa"];
	LCTerm *searchTerm2 = [[LCTerm alloc] initWithField: @"content" text: @"bbb"];
	
	//  add 100 documents with term : aaa
	LCIndexWriter *writer  = [[LCIndexWriter alloc] initWithDirectory: dir
															 analyzer: [[LCWhitespaceAnalyzer alloc] init]
															   create: YES];
	int i;
	for (i = 0; i < 100; i++)
    {
		[self _addDoc: writer value: [searchTerm text]];
    }
	[writer close];
	
	// OPEN READER AT THIS POINT - this should fix the view of the
	// index at the point of having 100 "aaa" documents and 0 "bbb"
	LCIndexReader *reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	UKIntsEqual(0, [reader documentFrequency: searchTerm2]);
	[self _assertTermDocsCount: @"first reader" reader: reader
						  term: searchTerm expected: 100];
	[self _assertTermDocsCount: @"first reader" reader: reader
						  term: searchTerm2 expected: 0];
	
	// add 100 documents with term : bbb
	writer  = [[LCIndexWriter alloc] initWithDirectory: dir
											  analyzer: [[LCWhitespaceAnalyzer alloc] init]
												create: NO];
	for (i = 0; i < 100; i++)
    {
		[self _addDoc: writer value: [searchTerm2 text]];
    }
	
	// REQUEST OPTIMIZATION
	// This causes a new segment to become current for all subsequent
	// searchers. Because of this, deletions made via a previously open
	// reader, which would be applied to that reader's segment, are lost
	// for subsequent searchers/readers
	if(optimize)
		[writer optimize];
	[writer close];
	
	// The reader should not see the new data
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	UKIntsEqual(0, [reader documentFrequency: searchTerm2]);
	[self _assertTermDocsCount: @"first reader" reader: reader
						  term: searchTerm expected: 100];
	[self _assertTermDocsCount: @"first reader" reader: reader
						  term: searchTerm2 expected: 0];
	
	
	// DELETE DOCUMENTS CONTAINING TERM: aaa
	// NOTE: the reader was created when only "aaa" documents were in
#if 0
	try {
		deleted = reader.delete(searchTerm);
		fail("Delete allowed on an index reader with stale segment information");
	} catch (IOException e) {
		/* success */
	}
#endif
	
	// Re-open index reader and try again. This time it should see
	// the new data.
	[reader close];
	reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	UKIntsEqual(100, [reader documentFrequency: searchTerm2]);
	[self _assertTermDocsCount: @"first reader" reader: reader
						  term: searchTerm expected: 100];
	[self _assertTermDocsCount: @"first reader" reader: reader
						  term: searchTerm2 expected: 100];
	
	int deleted = [reader deleteTerm: searchTerm];
	UKIntsEqual(100, deleted);
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	UKIntsEqual(100, [reader documentFrequency: searchTerm2]);
	[self _assertTermDocsCount: @"deleted termDocs" reader: reader
						  term: searchTerm expected: 0];
	[self _assertTermDocsCount: @"deleted termDocs" reader: reader
						  term: searchTerm2 expected: 100];
	[reader close];
	
	// CREATE A NEW READER and re-test
	reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader documentFrequency: searchTerm]);
	UKIntsEqual(100, [reader documentFrequency: searchTerm2]);
	[self _assertTermDocsCount: @"deleted termDocs" reader: reader
						  term: searchTerm expected: 0];
	[self _assertTermDocsCount: @"deleted termDocs" reader: reader
						  term: searchTerm2 expected: 100];
	[reader close];
}

- (void) testDeleteRWConfUnoptimized
{
	[self _deleteRWConflict: NO];
}

- (void) testDeleteRWConfOptimized
{
	[self _deleteRWConflict: YES];
}

#if 0
private Directory getDirectory(boolean create) throws IOException {
    return FSDirectory.getDirectory(new File(System.getProperty("tempDir"), "testIndex"), create);
}
#endif

#if 0
public void testFilesOpenClose() throws IOException
{
	// Create initial data set
	Directory dir = getDirectory(true);
	IndexWriter writer  = new IndexWriter(dir, new WhitespaceAnalyzer(), true);
	addDoc(writer, "test");
	writer.close();
	dir.close();
	
	// Try to erase the data - this ensures that the writer closed all files
	dir = getDirectory(true);
	
	// Now create the data set again, just as before
	writer  = new IndexWriter(dir, new WhitespaceAnalyzer(), true);
	addDoc(writer, "test");
	writer.close();
	dir.close();
	
	// Now open existing directory and test that reader closes all files
	dir = getDirectory(false);
	IndexReader reader1 = IndexReader.open(dir);
	reader1.close();
	dir.close();
	
	// The following will fail if reader did not close all files
	dir = getDirectory(true);
}
#endif

- (void) _deleteRRConflict: (BOOL) optimize
{
	id <LCDirectory> dir = [[LCRAMDirectory alloc] init];
	// Should test on real file system
	// Directory dir = getDirectory(true);
	
	LCTerm *searchTerm1 = [[LCTerm alloc] initWithField: @"content" text: @"aaa"];
	LCTerm *searchTerm2 = [[LCTerm alloc] initWithField: @"content" text: @"bbb"];
	LCTerm *searchTerm3 = [[LCTerm alloc] initWithField: @"content" text: @"ccc"];
	
	//  add 100 documents with term : aaa
	//  add 100 documents with term : bbb
	//  add 100 documents with term : ccc
	LCIndexWriter *writer  = [[LCIndexWriter alloc] initWithDirectory: dir
															 analyzer: [[LCWhitespaceAnalyzer alloc] init]
															   create: YES];
	int i;
	for (i = 0; i < 100; i++)
    {
		[self _addDoc: writer value: [searchTerm1 text]];
		[self _addDoc: writer value: [searchTerm2 text]];
		[self _addDoc: writer value: [searchTerm3 text]];
    }
	if(optimize)
		[writer optimize];
	[writer close];
	
	// OPEN TWO READERS
	// Both readers get segment info as exists at this time
	LCIndexReader *reader1 = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"first opened"
						reader: reader1 term: searchTerm1 expected: 100];
	[self _assertTermDocsCount: @"first opened"
						reader: reader1 term: searchTerm2 expected: 100];
	[self _assertTermDocsCount: @"first opened"
						reader: reader1 term: searchTerm3 expected: 100];
	
	LCIndexReader *reader2 = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"first opened"
						reader: reader2 term: searchTerm1 expected: 100];
	[self _assertTermDocsCount: @"first opened"
						reader: reader2 term: searchTerm2 expected: 100];
	[self _assertTermDocsCount: @"first opened"
						reader: reader2 term: searchTerm3 expected: 100];
	
	// DELETE DOCS FROM READER 2 and CLOSE IT
	// delete documents containing term: aaa
	// when the reader is closed, the segment info is updated and
	// the first reader is now stale
	[reader2 deleteTerm: searchTerm1];
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"after delete 1"
						reader: reader2 term: searchTerm1 expected: 0];
	[self _assertTermDocsCount: @"after delete 1"
						reader: reader2 term: searchTerm2 expected: 100];
	[self _assertTermDocsCount: @"after delete 1"
						reader: reader2 term: searchTerm3 expected: 100];
	[reader2 close];
	
	// Make sure reader 1 is unchanged since it was open earlier
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"after delete 1"
						reader: reader1 term: searchTerm1 expected: 100];
	[self _assertTermDocsCount: @"after delete 1"
						reader: reader1 term: searchTerm2 expected: 100];
	[self _assertTermDocsCount: @"after delete 1"
						reader: reader1 term: searchTerm3 expected: 100];
	
	
	// ATTEMPT TO DELETE FROM STALE READER
	// delete documents containing term: bbb
#if 0
	try {
		reader1.delete(searchTerm2);
		fail("Delete allowed from a stale index reader");
	} catch (IOException e) {
		/* success */
	}
#endif
	// RECREATE READER AND TRY AGAIN
	[reader1 close];
	reader1 = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"reopened"
						reader: reader1 term: searchTerm1 expected: 0];
	[self _assertTermDocsCount: @"reopened"
						reader: reader1 term: searchTerm2 expected: 100];
	[self _assertTermDocsCount: @"reopened"
						reader: reader1 term: searchTerm3 expected: 100];
	
	[reader1 deleteTerm: searchTerm2];
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader1 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"deleted 2"
						reader: reader1 term: searchTerm1 expected: 0];
	[self _assertTermDocsCount: @"deleted 2"
						reader: reader1 term: searchTerm2 expected: 0];
	[self _assertTermDocsCount: @"deleted 2"
						reader: reader1 term: searchTerm3 expected: 100];
	[reader1 close];
	
	// Open another reader to confirm that everything is deleted
	reader2 = [LCIndexReader openDirectory: dir];
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm1]);
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm2]);
	UKIntsEqual(100, [reader2 documentFrequency: searchTerm3]);
	[self _assertTermDocsCount: @"reopened 2"
						reader: reader2 term: searchTerm1 expected: 0];
	[self _assertTermDocsCount: @"reopened 2"
						reader: reader2 term: searchTerm2 expected: 0];
	[self _assertTermDocsCount: @"reopened 2"
						reader: reader2 term: searchTerm3 expected: 100];
	[reader2 close];
	[dir close];
}

- (void) testDeleteRRConfUnoptimized
{
	[self _deleteRRConflict: NO];
}

- (void) testDeleteRRConfOptimized
{
	[self _deleteRRConflict: YES];
}

@end
