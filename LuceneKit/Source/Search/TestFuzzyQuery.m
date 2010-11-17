#include "LuceneKit.h"
#include <UnitKit/UnitKit.h>
#include "GNUstep.h"

static NSString *FIELD = @"field";

@interface TestFuzzyQuery: NSObject <UKTest>
@end

@implementation TestFuzzyQuery

- (void) addDoc: (NSString *) text : (LCIndexWriter *) writer
{
	LCDocument *doc = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName: FIELD string: text store: LCStore_YES
											 index: LCIndex_Tokenized];
	[doc addField: field];
	[writer addDocument: doc];
	DESTROY(field);
	DESTROY(doc);
}

- (void) testFuzziness
{
	LCRAMDirectory *directory = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: directory analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	[self addDoc: @"aaaaa" : writer];
	[self addDoc: @"aaaab" : writer];
	[self addDoc: @"aaabb" : writer];
	[self addDoc: @"aabbb" : writer];
	[self addDoc: @"abbbb" : writer];
	[self addDoc: @"bbbbb" : writer];
	[self addDoc: @"ddddd" : writer];
	[writer optimize];
	[writer close];
	
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: directory];

	LCTerm *t = [[LCTerm alloc] initWithField: FIELD text: @"aaaaa"];
	LCFuzzyQuery *query = [[LCFuzzyQuery alloc] initWithTerm: t
										   minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
												prefixLength: 0];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 1];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 2];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 3];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);

	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 4];
	hits = [searcher search: query];
	UKIntsEqual(2, [hits count]);
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 5];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 6];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	
    // not similar enough:
	t = [[LCTerm alloc] initWithField: FIELD text: @"xxxxx"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"aaccc"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);

    // query identical to a word in the index:
	t = [[LCTerm alloc] initWithField: FIELD text: @"aaaaa"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaa");
	UKStringsEqual([[hits document: 1] stringForField: FIELD], @"aaaab");
	UKStringsEqual([[hits document: 2] stringForField: FIELD], @"aaabb");

    // query similar to a word in the index:
	t = [[LCTerm alloc] initWithField: FIELD text: @"aaaac"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaa");
	UKStringsEqual([[hits document: 1] stringForField: FIELD], @"aaaab");
	UKStringsEqual([[hits document: 2] stringForField: FIELD], @"aaabb");
	
    // now with prefix
	t = [[LCTerm alloc] initWithField: FIELD text: @"aaaac"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 1];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaa");
	UKStringsEqual([[hits document: 1] stringForField: FIELD], @"aaaab");
	UKStringsEqual([[hits document: 2] stringForField: FIELD], @"aaabb");
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 2];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaa");
	UKStringsEqual([[hits document: 1] stringForField: FIELD], @"aaaab");
	UKStringsEqual([[hits document: 2] stringForField: FIELD], @"aaabb");
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 3];
	hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaa");
	UKStringsEqual([[hits document: 1] stringForField: FIELD], @"aaaab");
	UKStringsEqual([[hits document: 2] stringForField: FIELD], @"aaabb");
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 4];
	hits = [searcher search: query];
	UKIntsEqual(2, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaa");
	UKStringsEqual([[hits document: 1] stringForField: FIELD], @"aaaab");
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 5];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"ddddX"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"ddddd");
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 1];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"ddddd");

	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 2];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"ddddd");
	
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 3];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"ddddd");

	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 4];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"ddddd");

	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 5];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
    // different field = no match:
	t = [[LCTerm alloc] initWithField: @"anotherfield" text: @"ddddX"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);

	[searcher close];
	[directory close];
}

- (void) testFuzzinessLong
{	
	LCRAMDirectory *directory = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: directory analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	[self addDoc: @"aaaaaaa" : writer];
	[self addDoc: @"segment" : writer];
	[writer optimize];
	[writer close];
	
	
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: directory];
	
	// not similar enough:
	LCTerm *t = [[LCTerm alloc] initWithField: FIELD text: @"xxxxx"];
	LCFuzzyQuery *query = [[LCFuzzyQuery alloc] initWithTerm: t
										   minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
												prefixLength: 0];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
	// edit distance to "aaaaaaa" = 3, this matches because the string is longer than
    // in testDefaultFuzziness so a bigger difference is allowed:
	t = [[LCTerm alloc] initWithField: FIELD text: @"aaaaccc"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaaaa");

	// now with prefix
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 1];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaaaa");

	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 4];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	UKStringsEqual([[hits document: 0] stringForField: FIELD], @"aaaaaaa");

	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 5];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);	

    // no match, more than half of the characters is wrong:
	t = [[LCTerm alloc] initWithField: FIELD text: @"aaaCccc"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
    // now with prefix
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 2];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
	// "student" and "stellent" are indeed similar to "segment" by default:
	t = [[LCTerm alloc] initWithField: FIELD text: @"student"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	
	t = [[LCTerm alloc] initWithField: FIELD text: @"stellent"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);

	// now with prefix
	t = [[LCTerm alloc] initWithField: FIELD text: @"student"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 1];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);

	t = [[LCTerm alloc] initWithField: FIELD text: @"stellent"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 1];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);

	t = [[LCTerm alloc] initWithField: FIELD text: @"student"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 2];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);

	t = [[LCTerm alloc] initWithField: FIELD text: @"stellent"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: [LCFuzzyQuery defaultMinSimilarity]
								  prefixLength: 2];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
	// "student" doesn't match anymore thanks to increased minimum similarity:
	t = [[LCTerm alloc] initWithField: FIELD text: @"student"];
	query = [[LCFuzzyQuery alloc] initWithTerm: t
							 minimumSimilarity: 0.6f
								  prefixLength: 0];
	hits = [searcher search: query];
	UKIntsEqual(0, [hits count]);
	
#if 0
    try {
      query = new FuzzyQuery(new Term("field", "student"), 1.1f);
      fail("Expected IllegalArgumentException");
    } catch (IllegalArgumentException e) {
      // expecting exception
    }
    try {
      query = new FuzzyQuery(new Term("field", "student"), -0.1f);
      fail("Expected IllegalArgumentException");
    } catch (IllegalArgumentException e) {
      // expecting exception
    }
#endif
	[searcher close];
	[directory close];
}

@end
