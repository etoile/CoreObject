#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "LCSimpleAnalyzer.h"
#include "LCDocument.h"
#include "LCIndexWriter.h"
#include "LCTerm.h"
#include "LCBooleanClause.h"
#include "LCBooleanQuery.h"
#include "LCIndexSearcher.h"
#include "LCTermQuery.h"
#include "LCHits.h"
#include "LCRAMDirectory.h"

static NSString *FIELD_T = @"T";
static NSString *FIELD_C = @"C";

@interface TestBooleanOr: NSObject <UKTest>
{
	LCTermQuery *t1, *t2, *c1, *c2;
	LCIndexSearcher *searcher;
}
@end

@implementation TestBooleanOr

- (id) init
{
	self = [super init];
	LCTerm *t = [[LCTerm alloc] initWithField: FIELD_T text: @"files"];
	t1 = [[LCTermQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: FIELD_T text: @"deleting"];
	t2 = [[LCTermQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: FIELD_C text: @"production"];
	c1 = [[LCTermQuery alloc] initWithTerm: t];
	t = [[LCTerm alloc] initWithField: FIELD_C text: @"optimize"];
	c2 = [[LCTermQuery alloc] initWithTerm: t];
	
	LCRAMDirectory *rd = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: rd
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	LCField *f = [[LCField alloc] initWithName: FIELD_T
										string: @"Optimize not deleting all files"
										 store: LCStore_YES
										 index: LCIndex_Tokenized];
	LCDocument *d = [[LCDocument alloc] init];
	[d addField: f];
	f = [[LCField alloc] initWithName: FIELD_C
							   string: @"Deleted When I run an optimize in our production environment."
								store: LCStore_YES
								index: LCIndex_Tokenized];
	[d addField: f];
	[writer addDocument: d];
	[writer close];
	
	searcher = [[LCIndexSearcher alloc] initWithDirectory: rd];
	return self;
}

- (int) search: (LCQuery *) q
{
	return [[searcher search: q] count];
}

- (void) testElements
{
	UKIntsEqual(1, [self search: t1]);
	UKIntsEqual(1, [self search: t2]);
	UKIntsEqual(1, [self search: c1]);
	UKIntsEqual(1, [self search: c2]);
}

- (void) testFlat
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];
	LCBooleanClause *c = [[LCBooleanClause alloc] initWithQuery: t1 occur: LCOccur_SHOULD];
	[q addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: t2 occur: LCOccur_SHOULD];
	[q addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: c1 occur: LCOccur_SHOULD];
	[q addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: c2 occur: LCOccur_SHOULD];
	[q addClause: c];
	UKIntsEqual(1, [self search: q]);
}

- (void) testParenthesisMust
{
	LCBooleanQuery *q3 = [[LCBooleanQuery alloc] init];
	LCBooleanClause *c = [[LCBooleanClause alloc] initWithQuery: t1 occur: LCOccur_SHOULD];
	[q3 addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: t2 occur: LCOccur_SHOULD];
	[q3 addClause: c];
	LCBooleanQuery *q4 = [[LCBooleanQuery alloc] init];
	c = [[LCBooleanClause alloc] initWithQuery: c1 occur: LCOccur_MUST];
	[q4 addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: c2 occur: LCOccur_MUST];
	[q4 addClause: c];
	LCBooleanQuery *q2 = [[LCBooleanQuery alloc] init];
	[q2 addQuery: q3 occur: LCOccur_SHOULD];
	[q2 addQuery: q4 occur: LCOccur_SHOULD];
	UKIntsEqual(1, [self search: q2]);
}

- (void) testParenthesisMust2
{
	LCBooleanQuery *q3 = [[LCBooleanQuery alloc] init];
	LCBooleanClause *c = [[LCBooleanClause alloc] initWithQuery: t1 occur: LCOccur_SHOULD];
	[q3 addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: t2 occur: LCOccur_SHOULD];
	[q3 addClause: c];
	LCBooleanQuery *q4 = [[LCBooleanQuery alloc] init];
	c = [[LCBooleanClause alloc] initWithQuery: c1 occur: LCOccur_SHOULD];
	[q4 addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: c2 occur: LCOccur_SHOULD];
	[q4 addClause: c];
	LCBooleanQuery *q2 = [[LCBooleanQuery alloc] init];
	[q2 addQuery: q3 occur: LCOccur_SHOULD];
	[q2 addQuery: q4 occur: LCOccur_MUST];
	UKIntsEqual(1, [self search: q2]);
}

- (void) testParenthesisShould
{
	LCBooleanQuery *q3 = [[LCBooleanQuery alloc] init];
	LCBooleanClause *c = [[LCBooleanClause alloc] initWithQuery: t1 occur: LCOccur_SHOULD];
	[q3 addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: t2 occur: LCOccur_SHOULD];
	[q3 addClause: c];
	LCBooleanQuery *q4 = [[LCBooleanQuery alloc] init];
	c = [[LCBooleanClause alloc] initWithQuery: c1 occur: LCOccur_SHOULD];
	[q4 addClause: c];
	c = [[LCBooleanClause alloc] initWithQuery: c2 occur: LCOccur_SHOULD];
	[q4 addClause: c];
	LCBooleanQuery *q2 = [[LCBooleanQuery alloc] init];
	[q2 addQuery: q3 occur: LCOccur_SHOULD];
	[q2 addQuery: q4 occur: LCOccur_SHOULD];
	UKIntsEqual(1, [self search: q2]);
}

@end

