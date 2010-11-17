#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCRAMDirectory.h"
#include "LCSimpleAnalyzer.h"
#include "LCDocument.h"
#include "LCIndexWriter.h"
#include "LCIndexSearcher.h"
#include "LCQuery.h"
#include "LCSort.h"
#include "LCTerm.h"
#include "LCTermQuery.h"
#include "LCSort.h"
#include "LCHits.h"
#include "LCSortField.h"
#include "LCFilter.h"
#include "LCTopFieldDocs.h"
#include "GNUstep.h"

@interface TestSortFilter: LCFilter
{
	LCTopDocs *td;
}
- (id) initWithTopDocs: (LCTopDocs *) topDocs;
@end

@interface TestSort: NSObject <UKTest>
{
	LCSearcher *full;
	LCSearcher *searchX;
	LCSearcher *searchY;
	LCQuery *queryX;
	LCQuery *queryY;
	LCQuery *queryA;
	LCQuery *queryE;
	LCQuery *queryF;
	LCQuery *queryG;
	LCSort *sort;
	NSArray *data;
}
@end

@implementation TestSort

	// create an index of all the documents, or just the x, or just the y documents
- (LCSearcher *) getIndex: (BOOL) even : (BOOL) odd
{
	LCRAMDirectory *indexStore = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: indexStore
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	int i;
	for (i = 0; i < [data count]; i++) {
		if (((i % 2) == 0 && even) || ((i % 2) == 1 && odd)) {
			LCDocument *doc = [[LCDocument alloc] init];
			LCField *field = [[LCField alloc] initWithName: @"tracer" string: [[data objectAtIndex: i] objectAtIndex: 0]
													 store: LCStore_YES index: LCIndex_NO];
			[doc addField: field];
			field = [[LCField alloc] initWithName: @"contents" string: [[data objectAtIndex: i] objectAtIndex: 1]
											store: LCStore_NO index: LCIndex_Tokenized];
			[doc addField: field];
			if ([[[data objectAtIndex: i] objectAtIndex: 2] isEqual: [NSNull null]] == NO)
			{
				field = [[LCField alloc] initWithName: @"int" string: [[data objectAtIndex: i] objectAtIndex: 2]
												store: LCStore_NO index: LCIndex_Untokenized];
				[doc addField: field];
			}
			if ([[[data objectAtIndex: i] objectAtIndex: 3] isEqual: [NSNull null]] == NO)
			{
				field = [[LCField alloc] initWithName: @"float" string: [[data objectAtIndex: i] objectAtIndex: 3]
												store: LCStore_NO index: LCIndex_Untokenized];
				[doc addField: field];
			}
			if ([[[data objectAtIndex: i] objectAtIndex: 4] isEqual: [NSNull null]] == NO)
			{
				field = [[LCField alloc] initWithName: @"string" string: [[data objectAtIndex: i] objectAtIndex: 4]
												store: LCStore_NO index: LCIndex_Untokenized];
				[doc addField: field];
			}
			if ([[[data objectAtIndex: i] objectAtIndex: 5] isEqual: [NSNull null]] == NO)
			{
				field = [[LCField alloc] initWithName: @"custom" string: [[data objectAtIndex: i] objectAtIndex: 5]
												store: LCStore_NO index: LCIndex_Untokenized];
				[doc addField: field];
			}
			[doc setBoost: 2];
			[writer addDocument: doc];
		}
	}
	[writer optimize];
	[writer close];
	return [[LCIndexSearcher alloc] initWithDirectory: indexStore];
}

- (LCSearcher *) getFullIndex
{
	return [self getIndex: YES : YES];
}

- (LCSearcher *) getXIndex
{
	return [self getIndex: YES : NO];
}

- (LCSearcher *) getYIndex
{
	return [self getIndex: NO : YES];
}

- (LCSearcher *) getEmptyIndex
{
	return [self getIndex: NO : NO];
}

- (id) init
{
	self = [super init];
	// document data:
	// the tracer field is used to determine which document was hit
	// the contents field is used to search and sort by relevance
	// the int field to sort by int
	// the float field to sort by float
	// the string field to sort by string
	data = [[NSArray alloc] initWithObjects:
		//							tracer	contents			int				float			string	custom
		[NSArray arrayWithObjects:	@"A",	@"x a",				@"5",			@"4f",			@"c",	@"A-3",	nil],
		[NSArray arrayWithObjects:	@"B",	@"y a",				@"5",			@"3.4028235E38",@"i",	@"B-10", nil],
		[NSArray arrayWithObjects:	@"C",	@"x a b c",			@"2147483647",	@"1.0",			@"j",	@"A-2", nil],
		[NSArray arrayWithObjects:	@"D",	@"y a b c",			@"-1",			@"0.0f",		@"a",	@"C-0", nil],
		[NSArray arrayWithObjects:	@"E",	@"x a b c d",		@"5",			@"2f",			@"h",	@"B-8", nil],
		[NSArray arrayWithObjects:	@"F",	@"y a b c d",		@"2",			@"3.14159f",	@"g",	@"B-1", nil],
		[NSArray arrayWithObjects:	@"G",	@"x a b c d",		@"3",			@"-1.0",		@"f",	@"C-100", nil],
		[NSArray arrayWithObjects:	@"H",	@"y a b c d",		@"0",			@"1.4E-45",		@"e",	@"C-88", nil],
		[NSArray arrayWithObjects:	@"I",	@"x a b c d e f",	@"-2147483648",	@"1.0e+0",		@"d",	@"A-10", nil],
		[NSArray arrayWithObjects:	@"J",	@"y a b c d e f",	@"4",			@".5",			@"b",	@"C-7", nil],
		[NSArray arrayWithObjects:	@"W",	@"g",				@"1",	[NSNull null],	[NSNull null],	[NSNull null], nil],
		[NSArray arrayWithObjects:	@"X",	@"g",				@"1",	@"0.1",	[NSNull null],	[NSNull null], nil],
		[NSArray arrayWithObjects:	@"Y",	@"g",				@"1",	@"0.2",	[NSNull null],	[NSNull null], nil],
		[NSArray arrayWithObjects:	@"Z",	@"f g",				[NSNull null],	[NSNull null],	[NSNull null],	[NSNull null], nil],
		nil];
	ASSIGN(full, [self getFullIndex]);
	ASSIGN(searchX, [self getXIndex]);
	ASSIGN(searchY, [self getYIndex]);
	LCTerm *term = [[LCTerm alloc] initWithField: @"contents" text: @"x"];
	ASSIGN(queryX, [[LCTermQuery alloc] initWithTerm: term]);
	term = [[LCTerm alloc] initWithField: @"contents" text: @"y"];
	ASSIGN(queryY, [[LCTermQuery alloc] initWithTerm: term]);
	term = [[LCTerm alloc] initWithField: @"contents" text: @"a"];
	ASSIGN(queryA, [[LCTermQuery alloc] initWithTerm: term]);
	term = [[LCTerm alloc] initWithField: @"contents" text: @"e"];
	ASSIGN(queryE, [[LCTermQuery alloc] initWithTerm: term]);
	term = [[LCTerm alloc] initWithField: @"contents" text: @"f"];
	ASSIGN(queryF, [[LCTermQuery alloc] initWithTerm: term]);
	term = [[LCTerm alloc] initWithField: @"contents" text: @"g"];
	ASSIGN(queryG, [[LCTermQuery alloc] initWithTerm: term]);
	ASSIGN(sort, [[LCSort alloc] init]);
	return self;
}

// make sure the documents returned by the search match the expected list
- (void) assertMatches: (LCSearcher *) searcher query: (LCQuery *) query sort: (LCSort *) s expected: (NSString *) expectedResult
{
	LCHits *result = [searcher search: query sort: s];
	NSMutableString *buff = [[NSMutableString alloc] init];
	int i, n = [result count];
	for (i = 0; i < n; i++) {
		LCDocument *doc = [result document: i];
		NSArray *v = [doc allStringsForField: @"tracer"];
		int j;
		for (j = 0; j < [v count]; j++) {
			[buff appendString: [v objectAtIndex: j]];
		}
	}
	UKStringsEqual(expectedResult, buff);
}

// test the sorts by score and document number
- (void) testBuiltInSorts
{
	LCSort *s = [[LCSort alloc] init];
	[self assertMatches: full query: queryX sort: s expected: @"ACEGI"];
	[self assertMatches: full query: queryY sort: s expected: @"BDFHJ"];
	[s setSortField: [LCSortField sortField_DOC]];
	[self assertMatches: full query: queryX sort: s expected: @"ACEGI"];
	[self assertMatches: full query: queryY sort: s expected: @"BDFHJ"];
}

// test sorts where the type of field is specified
- (void) testTypedSort
{
	LCSortField *sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT];
	NSArray *fields = [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil];
	[sort setSortFields: fields];
	[self assertMatches: full query: queryX sort: sort expected: @"IGAEC"];
	[self assertMatches: full query: queryY sort: sort expected: @"DHFJB"];
	
	sf = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	fields = [NSArray arrayWithObjects: sf, nil];
	[sort setSortFields: fields];
	[self assertMatches: full query: queryX sort: sort expected: @"GCIEA"];
	[self assertMatches: full query: queryY sort: sort expected: @"DHJFB"];
	
	sf = [[LCSortField alloc] initWithField: @"string" type: LCSortField_STRING];
	fields = [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil];
	[sort setSortFields: fields];
	[self assertMatches: full query: queryX sort: sort expected: @"AIGEC"];
	[self assertMatches: full query: queryY sort: sort expected: @"DJHFB"];
}

// test sorts when there's nothing in the index
- (void) testEmptyIndex
{
	LCSearcher *empty = [self getEmptyIndex];
	sort = [[LCSort alloc] init];
	[self assertMatches: empty query: queryX sort: sort expected: @""];
	
	[sort setSortField: [LCSortField sortField_DOC]];
	[self assertMatches: empty query: queryX sort: sort expected: @""];

	LCSortField *sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT];
	NSArray *fields = [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil];
	[sort setSortFields: fields];
	[self assertMatches: empty query: queryX sort: sort expected: @""];
	
	sf = [[LCSortField alloc] initWithField: @"string" type: LCSortField_STRING reverse: YES];
	fields = [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil];
	[sort setSortFields: fields];
	[self assertMatches: empty query: queryX sort: sort expected: @""];
	
	sf = [[LCSortField alloc] initWithField: @"string" type: LCSortField_STRING];
	LCSortField *sf1 = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	fields = [NSArray arrayWithObjects: sf1, sf, nil];
	[sort setSortFields: fields];
	[self assertMatches: empty query: queryX sort: sort expected: @""];
}

	// test sorts where the type of field is determined dynamically
#if 0
	public void testAutoSort() throws Exception {
		sort.setSort("int");
		assertMatches (full, queryX, sort, "IGAEC");
		assertMatches (full, queryY, sort, "DHFJB");

		sort.setSort("float");
		assertMatches (full, queryX, sort, "GCIEA");
		assertMatches (full, queryY, sort, "DHJFB");

		sort.setSort("string");
		assertMatches (full, queryX, sort, "AIGEC");
		assertMatches (full, queryY, sort, "DJHFB");
	}
#endif

	// test sorts in reverse
- (void) testReverseSort
{
	LCSortField *sf = [[LCSortField alloc] initWithField: nil type: LCSortField_SCORE reverse: YES];
	NSArray *fields = [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil];
	[sort setSortFields: fields];
	[self assertMatches: full query: queryX sort: sort expected: @"IEGCA"];
	[self assertMatches: full query: queryY sort: sort expected: @"JFHDB"];
	
	sf = [[LCSortField alloc] initWithField: nil type: LCSortField_DOC reverse: YES];
	[sort setSortField: sf];
	[self assertMatches: full query: queryX sort: sort expected: @"IGECA"];
	[self assertMatches: full query: queryY sort: sort expected: @"JHFDB"];
	
	[sort setField: @"int" reverse: YES];
	[self assertMatches: full query: queryX sort: sort expected: @"CAEGI"];
	[self assertMatches: full query: queryY sort: sort expected: @"BJFHD"];

	[sort setField: @"float" reverse: YES];
	[self assertMatches: full query: queryX sort: sort expected: @"AECIG"];
	[self assertMatches: full query: queryY sort: sort expected: @"BFJHD"];
	
	[sort setField: @"string" reverse: YES];
	[self assertMatches: full query: queryX sort: sort expected: @"CEGIA"];
	[self assertMatches: full query: queryY sort: sort expected: @"BFHJD"];
}

// test sorting when the sort field is empty (undefined) for some of the documents
- (void) testEmptyFieldSort
{
	LCSortField *sf;
	[sort setField: @"string"];
	[self assertMatches: full query: queryF sort: sort expected: @"ZJI"];

	[sort setField: @"string" reverse: YES];
	[self assertMatches: full query: queryF sort: sort expected: @"IJZ"];
	
	sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT reverse: NO];
	[sort setSortField: sf];
	[self assertMatches: full query: queryF sort: sort expected: @"IZJ"];

	/* LuceneKit: avoid to use LCSortField_AUTO because it might not work properly */
	sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT reverse: YES];
	[sort setSortField: sf];
	[self assertMatches: full query: queryF sort: sort expected: @"JZI"];

	sf = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	[sort setSortFields: [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil]];
	[self assertMatches: full query: queryF sort: sort expected: @"ZJI"];
	
	// using a nonexisting field as first sort key shouldn't make a difference:
	sf = [[LCSortField alloc] initWithField: @"nosuchfield" type: LCSortField_STRING];
	LCSortField *sf1 = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	[sort setSortFields: [NSArray arrayWithObjects: sf, sf1, nil]];
	[self assertMatches: full query: queryF sort: sort expected: @"ZJI"];
	
	sf = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT reverse: YES];
	[sort setSortFields: [NSArray arrayWithObjects: sf, [LCSortField sortField_DOC], nil]];
	[self assertMatches: full query: queryF sort: sort expected: @"IJZ"];

	sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT];
	sf1 = [[LCSortField alloc] initWithField: @"string" type: LCSortField_STRING];
	LCSortField *sf2 = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	[sort setSortFields: [NSArray arrayWithObjects: sf, sf1, sf2, nil]];
	[self assertMatches: full query: queryG sort: sort expected: @"ZWXY"];

	sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT];
	sf1 = [[LCSortField alloc] initWithField: @"string" type: LCSortField_STRING];
	sf2 = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT reverse: YES];
	[sort setSortFields: [NSArray arrayWithObjects: sf, sf1, sf2, nil]];
	[self assertMatches: full query: queryG sort: sort expected: @"ZYXW"];

#if 0
 // Do the same for a MultiSearcher
 	                 Searcher multiSearcher=new MultiSearcher (new Searchable[] { full });
 	 
 	                 sort.setSort (new SortField[] { new SortField ("int"),
 	                                 new SortField ("string", SortField.STRING),
 	                                 new SortField ("float") });
 	                 assertMatches (multiSearcher, queryG, sort, "ZWXY");
 	 
 	                 sort.setSort (new SortField[] { new SortField ("int"),
 	                                 new SortField ("string", SortField.STRING),
 	                                 new SortField ("float", true) });
 	                 assertMatches (multiSearcher, queryG, sort, "ZYXW");
 	                 // Don't close the multiSearcher. it would close the full searcher too!
 	 
 	                 // Do the same for a ParallelMultiSearcher
 	                 Searcher parallelSearcher=new ParallelMultiSearcher (new Searchable[] { full });
 	 
 	                 sort.setSort (new SortField[] { new SortField ("int"),
 	                                 new SortField ("string", SortField.STRING),
 	                                 new SortField ("float") });
 	                 assertMatches (parallelSearcher, queryG, sort, "ZWXY");
 	 
 	                 sort.setSort (new SortField[] { new SortField ("int"),
 	                                 new SortField ("string", SortField.STRING),
 	                                 new SortField ("float", true) });
 	                 assertMatches (parallelSearcher, queryG, sort, "ZYXW");
 	                 // Don't close the parallelSearcher. it would close the full searcher too!
#endif
}

// test sorts using a series of fields
- (void) testSortCombos
{
	LCSortField *sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT];
	LCSortField *sf1 = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	[sort setSortFields: [NSArray arrayWithObjects: sf, sf1, nil]];
	[self assertMatches: full query: queryX sort: sort expected: @"IGEAC"];
	
	sf = [[LCSortField alloc] initWithField: @"int" type: LCSortField_INT reverse: YES];
	sf1 = [[LCSortField alloc] initWithField: nil type: LCSortField_DOC reverse: YES];
	[sort setSortFields: [NSArray arrayWithObjects: sf, sf1, nil]];
	[self assertMatches: full query: queryX sort: sort expected: @"CEAGI"];
	
	sf = [[LCSortField alloc] initWithField: @"float" type: LCSortField_FLOAT];
	sf1 = [[LCSortField alloc] initWithField: @"string" type: LCSortField_STRING];
	[sort setSortFields: [NSArray arrayWithObjects: sf, sf1, nil]];
	[self assertMatches: full query: queryX sort: sort expected: @"GICEA"];
}

- (void) testTopDocsScores
{
	LCSort *s = [[LCSort alloc] init];
	int nDocs = 10;

	LCTopFieldDocs *docs1 = [full searchQuery: queryE filter: nil
				 maximum: nDocs sort: s];
	TestSortFilter *sf = [[TestSortFilter alloc] initWithTopDocs: docs1];
	LCTopFieldDocs *docs2 = [full searchQuery: queryE filter: sf
			      	 maximum: nDocs sort: s];
	UKFloatsEqual([[[docs1 scoreDocuments] objectAtIndex: 0] score],
		      [[[docs2 scoreDocuments] objectAtIndex: 0] score],
			0.000001f);

 	// assertEquals(docs1.scoreDocs[0].score, docs2.scoreDocs[0].score, 1e-6);
}


#if 0
	// test using a Locale for sorting strings
	public void testLocaleSort() throws Exception {
		sort.setSort (new SortField[] { new SortField ("string", Locale.US) });
		assertMatches (full, queryX, sort, "AIGEC");
		assertMatches (full, queryY, sort, "DJHFB");

		sort.setSort (new SortField[] { new SortField ("string", Locale.US, true) });
		assertMatches (full, queryX, sort, "CEGIA");
		assertMatches (full, queryY, sort, "BFHJD");
	}

	// test a custom sort function
	public void testCustomSorts() throws Exception {
		sort.setSort (new SortField ("custom", SampleComparable.getComparatorSource()));
		assertMatches (full, queryX, sort, "CAIEG");
		sort.setSort (new SortField ("custom", SampleComparable.getComparatorSource(), true));
		assertMatches (full, queryY, sort, "HJDBF");
		SortComparator custom = SampleComparable.getComparator();
		sort.setSort (new SortField ("custom", custom));
		assertMatches (full, queryX, sort, "CAIEG");
		sort.setSort (new SortField ("custom", custom, true));
		assertMatches (full, queryY, sort, "HJDBF");
	}

	// test a variety of sorts using more than one searcher
	public void testMultiSort() throws Exception {
		MultiSearcher searcher = new MultiSearcher (new Searchable[] { searchX, searchY });
		runMultiSorts (searcher);
	}

	// test a variety of sorts using a parallel multisearcher
	public void testParallelMultiSort() throws Exception {
		Searcher searcher = new ParallelMultiSearcher (new Searchable[] { searchX, searchY });
		runMultiSorts (searcher);
	}

	// test a variety of sorts using a remote searcher
	public void testRemoteSort() throws Exception {
		Searchable searcher = getRemote();
		MultiSearcher multi = new MultiSearcher (new Searchable[] { searcher });
		runMultiSorts (multi);
	}

	// test custom search when remote
	public void testRemoteCustomSort() throws Exception {
		Searchable searcher = getRemote();
		MultiSearcher multi = new MultiSearcher (new Searchable[] { searcher });
		sort.setSort (new SortField ("custom", SampleComparable.getComparatorSource()));
		assertMatches (multi, queryX, sort, "CAIEG");
		sort.setSort (new SortField ("custom", SampleComparable.getComparatorSource(), true));
		assertMatches (multi, queryY, sort, "HJDBF");
		SortComparator custom = SampleComparable.getComparator();
		sort.setSort (new SortField ("custom", custom));
		assertMatches (multi, queryX, sort, "CAIEG");
		sort.setSort (new SortField ("custom", custom, true));
		assertMatches (multi, queryY, sort, "HJDBF");
	}

	// test that the relevancy scores are the same even if
	// hits are sorted
	public void testNormalizedScores() throws Exception {

		// capture relevancy scores
		HashMap scoresX = getScores (full.search (queryX));
		HashMap scoresY = getScores (full.search (queryY));
		HashMap scoresA = getScores (full.search (queryA));

		// we'll test searching locally, remote and multi
		MultiSearcher remote = new MultiSearcher (new Searchable[] { getRemote() });
		MultiSearcher multi  = new MultiSearcher (new Searchable[] { searchX, searchY });

		// change sorting and make sure relevancy stays the same

		sort = new Sort();
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort(SortField.FIELD_DOC);
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort ("int");
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort ("float");
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort ("string");
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort (new String[] {"int","float"});
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort (new SortField[] { new SortField ("int", true), new SortField (null, SortField.DOC, true) });
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

		sort.setSort (new String[] {"float","string"});
		assertSameValues (scoresX, getScores(full.search(queryX,sort)));
		assertSameValues (scoresX, getScores(remote.search(queryX,sort)));
		assertSameValues (scoresX, getScores(multi.search(queryX,sort)));
		assertSameValues (scoresY, getScores(full.search(queryY,sort)));
		assertSameValues (scoresY, getScores(remote.search(queryY,sort)));
		assertSameValues (scoresY, getScores(multi.search(queryY,sort)));
		assertSameValues (scoresA, getScores(full.search(queryA,sort)));
		assertSameValues (scoresA, getScores(remote.search(queryA,sort)));
		assertSameValues (scoresA, getScores(multi.search(queryA,sort)));

	}

	// runs a variety of sorts useful for multisearchers
	private void runMultiSorts (Searcher multi) throws Exception {
		sort.setSort (SortField.FIELD_DOC);
		assertMatchesPattern (multi, queryA, sort, "[AB]{2}[CD]{2}[EF]{2}[GH]{2}[IJ]{2}");

		sort.setSort (new SortField ("int", SortField.INT));
		assertMatchesPattern (multi, queryA, sort, "IDHFGJ[ABE]{3}C");

		sort.setSort (new SortField[] {new SortField ("int", SortField.INT), SortField.FIELD_DOC});
		assertMatchesPattern (multi, queryA, sort, "IDHFGJ[AB]{2}EC");

		sort.setSort ("int");
		assertMatchesPattern (multi, queryA, sort, "IDHFGJ[AB]{2}EC");

		sort.setSort (new SortField[] {new SortField ("float", SortField.FLOAT), SortField.FIELD_DOC});
		assertMatchesPattern (multi, queryA, sort, "GDHJ[CI]{2}EFAB");

		sort.setSort ("float");
		assertMatchesPattern (multi, queryA, sort, "GDHJ[CI]{2}EFAB");

		sort.setSort ("string");
		assertMatches (multi, queryA, sort, "DJAIHGFEBC");

		sort.setSort ("int", true);
		assertMatchesPattern (multi, queryA, sort, "C[AB]{2}EJGFHDI");

		sort.setSort ("float", true);
		assertMatchesPattern (multi, queryA, sort, "BAFE[IC]{2}JHDG");

		sort.setSort ("string", true);
		assertMatches (multi, queryA, sort, "CBEFGHIAJD");

		sort.setSort (new SortField[] { new SortField ("string", Locale.US) });
		assertMatches (multi, queryA, sort, "DJAIHGFEBC");

		sort.setSort (new SortField[] { new SortField ("string", Locale.US, true) });
		assertMatches (multi, queryA, sort, "CBEFGHIAJD");

		sort.setSort (new String[] {"int","float"});
		assertMatches (multi, queryA, sort, "IDHFGJEABC");

		sort.setSort (new String[] {"float","string"});
		assertMatches (multi, queryA, sort, "GDHJICEFAB");

		sort.setSort ("int");
		assertMatches (multi, queryF, sort, "IZJ");

		sort.setSort ("int", true);
		assertMatches (multi, queryF, sort, "JZI");

		sort.setSort ("float");
		assertMatches (multi, queryF, sort, "ZJI");

		sort.setSort ("string");
		assertMatches (multi, queryF, sort, "ZJI");

		sort.setSort ("string", true);
		assertMatches (multi, queryF, sort, "IJZ");
	}



	// make sure the documents returned by the search match the expected list pattern
	private void assertMatchesPattern (Searcher searcher, Query query, Sort sort, String pattern)
	throws IOException {
		Hits result = searcher.search (query, sort);
		StringBuffer buff = new StringBuffer(10);
		int n = result.length();
		for (int i=0; i<n; ++i) {
			Document doc = result.doc(i);
			String[] v = doc.getValues("tracer");
			for (int j=0; j<v.length; ++j) {
				buff.append (v[j]);
			}
		}
		// System.out.println ("matching \""+buff+"\" against pattern \""+pattern+"\"");
		assertTrue (Pattern.compile(pattern).matcher(buff.toString()).matches());
	}

	private HashMap getScores (Hits hits)
	throws IOException {
		HashMap scoreMap = new HashMap();
		int n = hits.length();
		for (int i=0; i<n; ++i) {
			Document doc = hits.doc(i);
			String[] v = doc.getValues("tracer");
			assertEquals (v.length, 1);
			scoreMap.put (v[0], new Float(hits.score(i)));
		}
		return scoreMap;
	}

	// make sure all the values in the maps match
	private void assertSameValues (HashMap m1, HashMap m2) {
		int n = m1.size();
		int m = m2.size();
		assertEquals (n, m);
		Iterator iter = m1.keySet().iterator();
		while (iter.hasNext()) {
			Object key = iter.next();
			assertEquals (m1.get(key), m2.get(key));
		}
	}

	private Searchable getRemote () throws Exception {
		try {
			return lookupRemote ();
		} catch (Throwable e) {
			startServer ();
			return lookupRemote ();
		}
	}

	private Searchable lookupRemote () throws Exception {
		return (Searchable) Naming.lookup ("//localhost/SortedSearchable");
	}

	private void startServer () throws Exception {
		// construct an index
		Searcher local = getFullIndex();
		// local.search (queryA, new Sort());

		// publish it
		Registry reg = LocateRegistry.createRegistry (1099);
		RemoteSearchable impl = new RemoteSearchable (local);
		Naming.rebind ("//localhost/SortedSearchable", impl);
	}

}
#endif

@end

@implementation TestSortFilter
- (id) initWithTopDocs: (LCTopDocs *) topDocs
{
	self = [self init];
	ASSIGN(td, topDocs);
	return self;
}

- (LCBitVector *) bits: (LCIndexReader *) reader
{
	LCBitVector *bv = [[LCBitVector alloc] initWithSize: [reader maximalDocument]];
	[bv setBit: [[[td scoreDocuments] objectAtIndex: 0] document]];
	return AUTORELEASE(bv);
}
@end
