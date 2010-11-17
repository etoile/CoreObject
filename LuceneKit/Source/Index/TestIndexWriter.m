#include "LCDocument.h"
#include "LCField.h"
#include "LCRAMDirectory.h"
#include "LCIndexWriter.h"
#include "LCIndexReader.h"
#include "LCWhitespaceAnalyzer.h"
#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>

@interface TestIndexWriter: NSObject <UKTest>
@end

@implementation TestIndexWriter

- (void) addDoc: (LCIndexWriter *) writer
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"content"
											string: @"aaa"
											 store: LCStore_NO
											 index: LCIndex_Tokenized];
	[doc addField: field];
	[writer addDocument: doc];
}

- (void) testDocCount
{
	id <LCDirectory> dir = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = nil;
	LCIndexReader *reader = nil;
	int i;
	
	writer  = [[LCIndexWriter alloc] initWithDirectory: dir
											  analyzer: [[LCWhitespaceAnalyzer alloc] init]
												create: YES];
	// add 300 documents
	int total = 300;
	for (i = 0; i < total; i++) {
		[self addDoc: writer];
	}
	UKIntsEqual(total, [writer numberOfDocuments]);
	[writer close];
	
	// delete 40 documents
	reader = [LCIndexReader openDirectory: dir];
	
	for (i = 0; i < 40; i++) {
		[reader deleteDocument: i];
	}
	[reader close];
	
	// test doc count before segments are merged/index is optimized
	writer = [[LCIndexWriter alloc] initWithDirectory: dir
											 analyzer: [[LCWhitespaceAnalyzer alloc] init]
											   create: NO];
	UKIntsEqual(total, [writer numberOfDocuments]);
	[writer close];
	
	reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(total, [reader maximalDocument]);
	UKIntsEqual(total-40, [reader numberOfDocuments]);
	[reader close];
	
	// optimize the index and check that the new doc count is correct
	writer = [[LCIndexWriter alloc] initWithDirectory: dir
											 analyzer: [[LCWhitespaceAnalyzer alloc] init]
											   create: NO]; 
	[writer optimize];
	UKIntsEqual(total-40, [writer numberOfDocuments]);
	[writer close];
	
	// check that the index reader gives the same numbers.
	reader = [LCIndexReader openDirectory: dir];
	UKIntsEqual(total-40, [reader maximalDocument]);
	UKIntsEqual(total-40, [reader numberOfDocuments]);
	[reader close];
	
	[dir close];
}

@end
