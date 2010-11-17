#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "GNUstep.h"
#include "LCSimpleAnalyzer.h"
#include "LCIndexReader.h"
#include "LCIndexWriter.h"
#include "LCRAMDirectory.h"
#include "LCDocument.h"

@interface TestBinaryDocument: NSObject <UKTest>
@end

@implementation TestBinaryDocument

- (void) testBinaryFieldInIndex
{
	NSString *binaryValStored = @"this text will be stored as a byte array in the index";
	NSString *binaryValCompressed = @"this text will be also stored and compressed as a byte array in the index";
	
    LCField *binaryFldStored = [[LCField alloc] initWithName: @"binaryStored" 
													   data: [binaryValStored dataUsingEncoding: NSUTF8StringEncoding]
													   store: LCStore_YES];
	LCField *binaryFldCompressed = [[LCField alloc] initWithName: @"binaryCompressed" 
													   data: [binaryValCompressed dataUsingEncoding: NSUTF8StringEncoding]
													   store: LCStore_Compress];
	LCField *stringFldStored = [[LCField alloc] initWithName: @"stringStored" 
													   string: binaryValStored
													   store: LCStore_YES
													   index: LCIndex_NO
												  termVector: LCTermVector_NO];
	LCField *stringFldCompressed = [[LCField alloc] initWithName: @"stringCompressed" 
													  string: binaryValCompressed
													   store: LCStore_Compress
													   index: LCIndex_NO
												  termVector: LCTermVector_NO];
#if 0
    try {
		// binary fields with store off are not allowed
		new Field("fail", binaryValCompressed.getBytes(), Field.Store.NO);
		fail();
    }
    catch (IllegalArgumentException iae) {
		;
    }
#endif
    
    LCDocument *doc = [[LCDocument alloc] init];
	[doc addField: binaryFldStored];
    [doc addField: binaryFldCompressed];
    [doc addField: stringFldStored];
    [doc addField: stringFldCompressed];
    
    /** test for field count */
    UKIntsEqual(4, [[doc fields] count]);
    
    /** add the doc to a ram index */
    LCRAMDirectory *dir = [[LCRAMDirectory alloc] init];
    LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: dir
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	[writer addDocument: doc];
	[writer close];
    
    /** open a reader and fetch the document */ 
    LCIndexReader *reader = [LCIndexReader openDirectory: dir];
    LCDocument *docFromReader = [reader document: 0];
	UKNotNil(docFromReader);

    /** fetch the binary stored field and compare it's content with the original one */
    NSString *binaryFldStoredTest = [[NSString alloc] initWithData: [docFromReader dataForField: @"binaryStored"]
														  encoding: NSUTF8StringEncoding];
	UKStringsEqual(binaryValStored, binaryFldStoredTest);

    /** fetch the binary compressed field and compare it's content with the original one */
	NSString *binaryFldCompressedTest = [[NSString alloc] initWithData: [docFromReader dataForField: @"binaryCompressed"]
														  encoding: NSUTF8StringEncoding];
	UKStringsEqual(binaryValCompressed, binaryFldCompressedTest);
	
    /** fetch the string field and compare it's content with the original one */
	NSString *stringFldStoredTest = [docFromReader stringForField: @"stringStored"];
	UKStringsEqual(binaryValStored, stringFldStoredTest);

    /** fetch the compressed string field and compare it's content with the original one */
	NSString *stringFldCompressedTest = [docFromReader stringForField: @"stringCompressed"];
	UKStringsEqual(binaryValCompressed, stringFldCompressedTest);

    /** delete the document from index */
	[reader deleteDocument: 0];
	UKIntsEqual(0, [reader numberOfDocuments]);

    [reader close];
}

@end
