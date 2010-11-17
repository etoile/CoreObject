#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCIndexWriter.h"
#include "LCRAMDirectory.h"
#include "LCSimpleAnalyzer.h"
#include "LCDocument.h"
#include "LCTermQuery.h"
#include "LCBooleanQuery.h"
#include "LCIndexSearcher.h"
#include "LCHits.h"

@interface TestNot: NSObject <UKTest>
@end

@implementation TestNot
- (void) testNot
{
	LCRAMDirectory *store = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: store
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	LCDocument *d1 = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: @"field" string: @"a b"
											 store: LCStore_YES index: LCIndex_Tokenized];
	[d1 addField: field];
	[writer addDocument: d1];
	[writer optimize];
	[writer close];

	// Query query = QueryParser.parse("a NOT b", "field", new SimpleAnalyzer());
	LCSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: store];
	LCBooleanQuery *query = [[LCBooleanQuery alloc] init];
	LCTerm *ta = [[LCTerm alloc] initWithField: @"field" text: @"a"];
	LCTermQuery *qa = [[LCTermQuery alloc] initWithTerm: ta];
	LCTerm *tb = [[LCTerm alloc] initWithField: @"field" text: @"b"];
	LCTermQuery *qb = [[LCTermQuery alloc] initWithTerm: tb];
	[query addQuery: qa occur: LCOccur_SHOULD];
	[query addQuery: qb occur: LCOccur_MUST_NOT];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
}
@end
