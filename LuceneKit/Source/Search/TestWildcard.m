#include "LuceneKit.h"
#include <UnitKit/UnitKit.h>

@interface TestWildcardQuery: NSObject <UKTest>
@end

@implementation TestWildcardQuery

- (void) assertMatches: (LCIndexSearcher *) searcher query: (LCQuery *) q expected: (int) expectedMatches
{
	LCHits *result = [searcher search: q];
	UKIntsEqual(expectedMatches, [result count]);
}

- (void) testEquals
{
	LCTerm *t = [[LCTerm alloc] initWithField: @"field" text: @"b*a"];
	LCWildcardQuery *wq1 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"field" text: @"b*a"];
	LCWildcardQuery *wq2 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"field" text: @"b*a"];
	LCWildcardQuery *wq3 = [[LCWildcardQuery alloc] initWithTerm: t];

	UKTrue([wq1 isEqual: wq2]);
	UKTrue([wq2 isEqual: wq1]);

	UKTrue([wq2 isEqual: wq3]);
	UKTrue([wq1 isEqual: wq3]);
	
	t = [[LCTerm alloc] initWithField: @"field" text: @"b*a"];
	LCFuzzyQuery *fq = [[LCFuzzyQuery alloc] initWithTerm: t];
	UKFalse([fq isEqual: wq1]);
	UKFalse([wq1 isEqual: fq]);
}

- (void) testWildcard
{
	LCRAMDirectory *indexStore = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: indexStore
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	int i;
	NSArray *strings = [[NSArray alloc] initWithObjects: @"metal", @"metals", nil];
	for (i = 0; i < [strings count]; i++)
	{
		LCField *field = [[LCField alloc] initWithName: @"body"
												string: [strings objectAtIndex: i]
												 store: LCStore_YES
												 index: LCIndex_Tokenized];
		LCDocument *doc = [[LCDocument alloc] init];
		[doc addField: field];
		[writer addDocument: doc];
	}
	[writer optimize];
	[writer close];
	
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: indexStore];
	LCTerm *t = [[LCTerm alloc] initWithField: @"body" text: @"metal"];
	LCQuery *query1 = [[LCTermQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"metal*"];
	LCQuery *query2 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"m*tal"];
	LCQuery *query3 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"m*tal*"];
	LCQuery *query4 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"m*tals"];
	LCQuery *query5 = [[LCWildcardQuery alloc] initWithTerm: t];
	
	LCBooleanQuery *query6 = [[LCBooleanQuery alloc] init];
	[query6 addQuery: query5 occur: LCOccur_SHOULD];

	LCBooleanQuery *query7 = [[LCBooleanQuery alloc] init];
	[query7 addQuery: query3 occur: LCOccur_SHOULD];
	[query7 addQuery: query5 occur: LCOccur_SHOULD];

	t = [[LCTerm alloc] initWithField: @"body"  text: @"M*tal*"];
	LCQuery *query8 = [[LCWildcardQuery alloc] initWithTerm: t];
	
	[self assertMatches: searcher query: query1 expected: 1];
	[self assertMatches: searcher query: query2 expected: 2];
	[self assertMatches: searcher query: query3 expected: 1];
	[self assertMatches: searcher query: query4 expected: 2];
	[self assertMatches: searcher query: query5 expected: 1];
	[self assertMatches: searcher query: query6 expected: 1];
	[self assertMatches: searcher query: query7 expected: 2];
	[self assertMatches: searcher query: query8 expected: 0];
	
	t = [[LCTerm alloc] initWithField: @"body"  text: @"*tall"];
	LCQuery *query9 = [[LCWildcardQuery alloc] initWithTerm: t];

	t = [[LCTerm alloc] initWithField: @"body"  text: @"*tal"];
	LCQuery *query10 = [[LCWildcardQuery alloc] initWithTerm: t];

	t = [[LCTerm alloc] initWithField: @"body"  text: @"*tal*"];
	LCQuery *query11 = [[LCWildcardQuery alloc] initWithTerm: t];
	
	[self assertMatches: searcher query: query9 expected: 0];
	[self assertMatches: searcher query: query10 expected: 1];
	[self assertMatches: searcher query: query11 expected: 2];
}

- (void) testQuestionmark
{
	LCRAMDirectory *indexStore = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: indexStore
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	int i;
	NSArray *strings = [[NSArray alloc] initWithObjects: @"metal", @"metals", @"mXtals", @"mXtXls", nil];
	for (i = 0; i < [strings count]; i++)
	{
		LCField *field = [[LCField alloc] initWithName: @"body"
												string: [strings objectAtIndex: i]
												 store: LCStore_YES
												 index: LCIndex_Tokenized];
		LCDocument *doc = [[LCDocument alloc] init];
		[doc addField: field];
		[writer addDocument: doc];
	}
	[writer optimize];
	[writer close];

	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: indexStore];
	LCTerm *t = [[LCTerm alloc] initWithField: @"body" text: @"m?tal"];
	LCQuery *query1 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"metal?"];
	LCQuery *query2 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"metals?"];
	LCQuery *query3 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"m?t?ls"];
	LCQuery *query4 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"M?t?ls"];
	LCQuery *query5 = [[LCWildcardQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: @"body"  text: @"meta??"];
	LCQuery *query6 = [[LCWildcardQuery alloc] initWithTerm: t];

	[self assertMatches: searcher query: query1 expected: 1];
	[self assertMatches: searcher query: query2 expected: 1];
	[self assertMatches: searcher query: query3 expected: 0];
	[self assertMatches: searcher query: query4 expected: 3];
	[self assertMatches: searcher query: query5 expected: 0];
	[self assertMatches: searcher query: query6 expected: 1];
}

@end
