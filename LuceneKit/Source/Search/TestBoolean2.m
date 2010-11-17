#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCRAMDirectory.h"
#include "LCIndexWriter.h"
#include "LCWhitespaceAnalyzer.h"
#include "LCDocument.h"
#include "LCIndexSearcher.h"
#include "LCTerm.h"
#include "LCTermQuery.h"
#include "LCBooleanQuery.h"
#include "LCHits.h"
#include "LCDefaultSimilarity.h"
#include "GNUstep.h"
#include "TestCheckHits.h"

static NSString *FIELD = @"field";

@interface TestSimilarity10: LCDefaultSimilarity
@end

@interface TestBoolean2: NSObject <UKTest>
{
	LCIndexSearcher *searcher;
}
@end

static NSArray *docFields = nil;

@implementation TestBoolean2

- (id) init
{
	self = [super init];
	LCRAMDirectory *directory = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: directory
															analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	if (docFields == nil)
	{
		docFields = [[NSArray alloc] initWithObjects: @"w1 w2 w3 w4 w5", 
			@"w1 w3 w2 w3",
			@"w1 xx w2 yy w3",
			@"w1 w3 xx w2 yy w3", nil];
	}
	int i;
	for (i = 0; i < [docFields count]; i++)
	{
		LCDocument *doc = [[LCDocument alloc] init];
		LCField *field = [[LCField alloc] initWithName: FIELD
												string: [docFields objectAtIndex: i]
												 store: LCStore_NO
												 index: LCIndex_Tokenized];
		[doc addField: field];
		[writer addDocument: doc];
	}
	[writer close];
	
	searcher = [[LCIndexSearcher alloc] initWithDirectory: directory];
	return self;
}

- (void) queries: (LCQuery *) query expDocNrs: (NSArray *) expDocNrs
{
	LCHits *hits = [searcher search: query];
	[TestCheckHits checkDocIds: hits results: expDocNrs];
}

- (void) testQueries01
{
	NSLog(@"Test Query \"+w3 +xx\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];

	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];

	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	NSArray *a = [NSArray arrayWithObjects: @"2", @"3", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries02
{
	NSLog(@"Test Query \"+w3 xx\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	NSArray *a = [NSArray arrayWithObjects: @"2", @"3", @"1", @"0", nil];
	[self queries: b expDocNrs: a];
}


- (void) testQueries03
{
	NSLog(@"Test Query \"w3 xx\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	NSArray *a = [NSArray arrayWithObjects: @"2", @"3", @"1", @"0", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries04
{
	NSLog(@"Test Query \"w3 -xx\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	NSArray *a = [NSArray arrayWithObjects: @"1", @"0", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries05
{
	NSLog(@"Test Query \"+w3 -xx\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	NSArray *a = [NSArray arrayWithObjects: @"1", @"0", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries06
{
	NSLog(@"Test Query \"+w3 -xx -w5\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];

	t = [[LCTerm alloc] initWithField: FIELD text: @"w5"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	
	NSArray *a = [NSArray arrayWithObjects: @"1", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries07
{
	NSLog(@"Test Query \"-w3 -xx -w5\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w5"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	
	NSArray *a = [[NSArray alloc] init];
	[self queries: b expDocNrs: a];
}

- (void) testQueries08
{
	NSLog(@"Test Query \"+w3 xx -w5\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w5"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST_NOT];
	
	NSArray *a = [NSArray arrayWithObjects: @"2", @"3", @"1", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries09
{
	NSLog(@"Test Query \"+w3 +xx +w2 zz\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w2"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"zz"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	
	NSArray *a = [NSArray arrayWithObjects: @"2", @"3", nil];
	[self queries: b expDocNrs: a];
}

- (void) testQueries10
{
	NSLog(@"Test Query \"+w3 +xx +w2 zz\"");
	LCTerm *t;
	LCTermQuery *q;
	LCBooleanQuery *b = [[LCBooleanQuery alloc] init];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w3"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"xx"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"w2"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_MUST];
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"zz"];
	q = [[LCTermQuery alloc] initWithTerm: t];
	[b addQuery: q occur: LCOccur_SHOULD];
	
	NSArray *a = [NSArray arrayWithObjects: @"2", @"3", nil];
	[searcher setSimilarity: [[TestSimilarity10 alloc] init]];
	[self queries: b expDocNrs: a];
}

@end

@implementation TestSimilarity10
- (float) coordination: (int) overlap max: (int) maxOverLap
{
	return (float)overlap / ((float)maxOverLap -1);
}
@end
