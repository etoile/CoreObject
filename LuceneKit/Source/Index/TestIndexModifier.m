#include "LCIndexModifier.h"
#include "LCRAMDirectory.h"
#include "LCWhitespaceAnalyzer.h"
#include "LCSimpleAnalyzer.h"
#include <UnitKit/UnitKit.h>

static int docCount = 0;

@interface TestIndexModifier: NSObject <UKTest>
@end

@interface TestIndexModifier1: LCIndexModifier <UKTest>
@end

@implementation TestIndexModifier1

- (void) iterateEnumerator
{
  [self assureOpen];
  [self createIndexReader];

  LCTermEnumerator *te = [indexReader termEnumerator];
  while ([te hasNextTerm])
  {
  }
}

@end

@implementation TestIndexModifier

- (void) testEmpty
{
  LCRAMDirectory *store = [[LCRAMDirectory alloc] init];
  LCAnalyzer *analyzer = [[LCWhitespaceAnalyzer alloc] init];
  TestIndexModifier1 *modifier = [[TestIndexModifier1 alloc] initWithDirectory: store analyzer: analyzer create: YES];

  [modifier iterateEnumerator];
}

- (LCDocument *) getDoc
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"body" string: [NSString stringWithFormat: @"%d", docCount]
											 store: LCStore_YES index: LCIndex_Untokenized];
	[doc addField: field];
	field = [[LCField alloc] initWithName: @"all" string: @"x"
									store: LCStore_YES index: LCIndex_Untokenized];
	[doc addField: field];
	docCount++;
	return doc;
}

- (void) testIndex
{
	LCTerm *allDocTerm = [[LCTerm alloc] initWithField: @"all" text: @"x"];
	id <LCDirectory> ramDir = [[LCRAMDirectory alloc] init];
	LCIndexModifier *i = [[LCIndexModifier alloc] initWithDirectory: ramDir
														   analyzer: [[LCWhitespaceAnalyzer alloc] init]
															 create: YES];
	[i addDocument: [self getDoc]];
	UKIntsEqual(1, [i numberOfDocuments]);
	[i flush];
	
	[i addDocument: [self getDoc] analyzer: [[LCSimpleAnalyzer alloc] init]];
	UKIntsEqual(2, [i numberOfDocuments]);
	[i optimize];
	UKIntsEqual(2, [i numberOfDocuments]);
	[i flush];
	
	[i deleteDocument: 0];
	UKIntsEqual(1, [i numberOfDocuments]);
	[i flush];
	UKIntsEqual(1, [i numberOfDocuments]);
	[i addDocument: [self getDoc]];
	[i addDocument: [self getDoc]];
	[i flush];
	UKIntsEqual(3, [i numberOfDocuments]);

	[i deleteTerm: allDocTerm];
	UKIntsEqual(0, [i numberOfDocuments]);
	[i optimize];
	UKIntsEqual(0, [i numberOfDocuments]);

    //  Lucene defaults:
	UKTrue([i useCompoundFile]);
	UKIntsEqual(10, [i maxBufferedDocuments]);
	UKIntsEqual(10000, [i maxFieldLength]);
	UKIntsEqual(10, [i mergeFactor]);
	[i setMaxBufferedDocuments: 100];
	[i setMergeFactor: 25];
	[i setMaxFieldLength: 250000];
	[i addDocument: [self getDoc]];
	[i setUseCompoundFile: NO];
	[i flush];
	UKFalse([i useCompoundFile]);
	UKIntsEqual(100, [i maxBufferedDocuments]);
	UKIntsEqual(250000, [i maxFieldLength]);
	UKIntsEqual(25, [i mergeFactor]);
	
	// test setting properties when internally the reader is opened:
	[i deleteTerm: allDocTerm];
	[i setMaxBufferedDocuments: 100];
	[i setMergeFactor: 25];
	[i setMaxFieldLength: 250000];
	[i addDocument: [self getDoc]];
	[i setUseCompoundFile: NO];
	[i optimize];
	UKFalse([i useCompoundFile]);
	UKIntsEqual(100, [i maxBufferedDocuments]);
	UKIntsEqual(250000, [i maxFieldLength]);
	UKIntsEqual(25, [i mergeFactor]);
	
	[i close];
  }

@end

