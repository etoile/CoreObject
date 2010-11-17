#include "LuceneKit.h"
#include <UnitKit/UnitKit.h>

@interface TestPrefixQuery: NSObject <UKTest>
@end

@implementation TestPrefixQuery
- (void) testPrefix
{
	LCRAMDirectory *directory = [[LCRAMDirectory alloc] init];
	NSArray *categories = [NSArray arrayWithObjects: @"/Computers", @"/Computers/Mac", @"/Computers/Windows", nil];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: directory
															analyzer: [[LCWhitespaceAnalyzer alloc] init]
															  create: YES];
	int i;
	for (i = 0; i < [categories count]; i++) {
		LCDocument *doc = [[LCDocument alloc] init];
		LCField *field = [[LCField alloc] initWithName: @"category" string: [categories objectAtIndex: i]
												 store: LCStore_YES index: LCIndex_Untokenized];
		[doc addField: field];
		[writer addDocument: doc];
	}
	[writer close];
	
	LCTerm *term = [[LCTerm alloc] initWithField: @"category" text: @"/Computers"];
	LCPrefixQuery *query = [[LCPrefixQuery alloc] initWithTerm: term];
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: directory];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(3, [hits count]);
	
	term = [[LCTerm alloc] initWithField: @"category" text: @"/Computers/Mac"];
	query = [[LCPrefixQuery alloc] initWithTerm: term];
	hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);

#if 0

		
		PrefixQuery query = new PrefixQuery(new Term("category", "/Computers"));
		IndexSearcher searcher = new IndexSearcher(directory);
		Hits hits = searcher.search(query);
		assertEquals("All documents in /Computers category and below", 3, hits.length
					 ());
		
		query = new PrefixQuery(new Term("category", "/Computers/Mac"));
		hits = searcher.search(query);
		assertEquals("One in /Computers/Mac", 1, hits.length());
	}
#endif
}

@end
