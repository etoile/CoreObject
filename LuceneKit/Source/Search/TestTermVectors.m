#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCSimpleAnalyzer.h"
#include "LCDocument.h"
#include "LCRAMDirectory.h"
#include "LCIndexSearcher.h"
#include "LCIndexWriter.h"
#include "LCIndexReader.h"
#include "LCTermPositionVector.h"
#include "LCTermQuery.h"
#include "LCHits.h"
#include "TestEnglish.h"

@interface TestTermVectors: NSObject <UKTest>
{
	LCIndexSearcher *searcher;
	LCRAMDirectory *directory;
}
@end

@implementation TestTermVectors

- (id) init
{
	self = [super init];
	directory = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: directory
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	int i, count = 1, total = 1000;
	NSLog(@"Build %d document(s) ...", total);
	for(i = 0; i < total; i++) {
		LCDocument *doc = [[LCDocument alloc] init];
		LCTermVector_Type termVector;
		int mod3 = i % 3;
		int mod2 = i % 2;
		if (mod2 == 0 && mod3 == 0) {
			termVector = LCTermVector_WithPositionsAndOffsets;
		} else if (mod2 == 0) {
			termVector = LCTermVector_WithPositions;
		} else if (mod3 == 0) {
			termVector = LCTermVector_WithOffsets;
		} else {
			termVector = LCTermVector_YES;
		}
		LCField *field = [[LCField alloc] initWithName: @"field" string: [TestEnglish intToEnglish: i] 
												 store: LCStore_YES index: LCIndex_Tokenized
											termVector: termVector];
		[doc addField: field];
		[writer addDocument: doc];
		if (i == count-1) {
			NSLog(@"%d document(s) ...", i+1);
			count *= 10;
		}
	}
	[writer close];
	NSLog(@"Document built");
	searcher = [[LCIndexSearcher alloc] initWithDirectory: directory];
	return self;
}

- (void) testBasic
{
	UKNotNil(searcher);
}

- (void) setupDoc: (LCDocument *) doc text: (NSString *) text
{
	LCField *field = [[LCField alloc] initWithName: @"field" string: text 
											 store: LCStore_YES index: LCIndex_Tokenized
										termVector: LCTermVector_YES];
	[doc addField: field];
}

- (void) testTermVectors
{
	LCTerm *term = [[LCTerm alloc] initWithField: @"field" text: @"seventy"];
	LCQuery *query = [[LCTermQuery alloc] initWithTerm: term];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(100, [hits count]);
	
	int i, count = [hits count];
	for (i = 0; i < count; i++) {
		NSArray *vector = [[searcher indexReader] termFrequencyVectors: [hits identifier: i]];
		UKNotNil(vector);
		UKIntsEqual(1, [vector count]);
	}
}

- (void) testTermPositionVectors
{
	LCTerm *term = [[LCTerm alloc] initWithField: @"field" text: @"zero"];
	LCQuery *query = [[LCTermQuery alloc] initWithTerm: term];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(1, [hits count]);
	int i, count = [hits count];
	for (i = 0; i < count; i++) 
	{
		NSArray *vector = [[searcher indexReader] termFrequencyVectors: [hits identifier: i]];
		UKNotNil(vector);
		UKIntsEqual(1, [vector count]);
		
		BOOL shouldBePosVector = ([hits identifier: i] % 2 == 0) ? YES : NO;
		UKTrue((shouldBePosVector == NO) ||
			   (shouldBePosVector == YES && ([[vector objectAtIndex: 0] conformsToProtocol: @protocol(LCTermPositionVector)] == YES)));

		BOOL shouldBeOffVector = ([hits identifier: i] % 3 == 0) ? YES : NO;
		UKTrue((shouldBeOffVector == NO) ||
			   (shouldBeOffVector == YES && ([[vector objectAtIndex: 0] conformsToProtocol: @protocol(LCTermPositionVector)] == YES)));
		
		if (shouldBePosVector || shouldBeOffVector) {
			id <LCTermPositionVector> posVec = [vector objectAtIndex: 0];
			NSArray *terms = [posVec allTerms];
			UKNotNil(terms);
			UKTrue([terms count] > 0);
			
			int j;
			for (j = 0; j < [terms count]; j++) {
				NSArray *positions = [posVec termPositions: j];
				NSArray *offsets = [posVec termOffsets: j];
				
				if (shouldBePosVector) {
					UKNotNil(positions);
					UKTrue([positions count] > 0);
				} else {
					UKNil(positions);
				}
				
				if (shouldBeOffVector) {
					UKNotNil(offsets);
					UKTrue([offsets count] > 0);
				} else {
					UKNil(offsets);
				}
			}
		} else {
			UKTrue([[vector objectAtIndex: 0] conformsToProtocol: @protocol(LCTermPositionVector)] == NO);
			id <LCTermFrequencyVector> freqVec = [vector objectAtIndex: 0];
			NSArray *terms = [freqVec allTerms];
			UKNotNil(terms);
			UKTrue([terms count] > 0);
		}
	}
}

- (void) testTermOffsetVectors
{
	LCTerm *term = [[LCTerm alloc] initWithField: @"field" text: @"fifty"];
	LCQuery *query = [[LCTermQuery alloc] initWithTerm: term];
	LCHits *hits = [searcher search: query];
	UKIntsEqual(100, [hits count]);
	int i, count = [hits count];
	for (i = 0; i < count; i++)
	{
		NSArray *vector = [[searcher indexReader] termFrequencyVectors: [hits identifier: i]];
		UKNotNil(vector);
		UKIntsEqual(1, [vector count]);
	}
}

- (void) testKnownSetOfDocuments
{
    NSString *test1 = @"eating chocolate in a computer lab"; //6 terms
    NSString *test2 = @"computer in a computer lab"; //5 terms
    NSString *test3 = @"a chocolate lab grows old"; //5 terms
    NSString *test4 = @"eating chocolate with a chocolate lab in an old chocolate colored computer lab"; //13 terms
	NSMutableDictionary *test4Map = [[NSMutableDictionary alloc] init];
	[test4Map setObject: [NSNumber numberWithInt: 3] forKey: @"chocolate"];
	[test4Map setObject: [NSNumber numberWithInt: 2] forKey: @"lab"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"eating"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"computer"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"with"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"a"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"colored"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"in"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"an"];
	[test4Map setObject: [NSNumber numberWithInt: 1] forKey: @"old"];

	LCDocument *testDoc1 = [[LCDocument alloc] init];
	[self setupDoc: testDoc1 text: test1];
	LCDocument *testDoc2 = [[LCDocument alloc] init];
	[self setupDoc: testDoc2 text: test2];
	LCDocument *testDoc3 = [[LCDocument alloc] init];
	[self setupDoc: testDoc3 text: test3];
	LCDocument *testDoc4 = [[LCDocument alloc] init];
	[self setupDoc: testDoc4 text: test4];
	
	id <LCDirectory> dir = [[LCRAMDirectory alloc] init];
	LCIndexWriter *w = [[LCIndexWriter alloc] initWithDirectory: dir
													   analyzer: [[LCSimpleAnalyzer alloc] init]
														 create: YES];
	UKNotNil(w);
	[w addDocument: testDoc1];
	[w addDocument: testDoc2];
	[w addDocument: testDoc3];
	[w addDocument: testDoc4];
	[w close];
	LCIndexSearcher *knownSearcher = [[LCIndexSearcher alloc] initWithDirectory: dir];
	LCTermEnumerator *termEnum = [[knownSearcher indexReader] termEnumerator];
	id <LCTermDocuments> termDocs = [[knownSearcher indexReader] termDocuments];
	//LCSimilarity *sim = [knownSearcher similarity];
	while ([termEnum hasNextTerm] == YES)
	{
		LCTerm *term = [termEnum term];
		[termDocs seekTerm: term];
		while ([termDocs hasNextDocument])
		{
			int docId = [termDocs document];
			int freq = [termDocs frequency];
			id <LCTermFrequencyVector> vector = [[knownSearcher indexReader] termFrequencyVector: docId 
																				 field: @"field"];
			//float tf = [sim termFrequencyWithInt: freq];
			//float idf = [sim inverseDocumentFrequencyWithTerm: term searcher: knownSearcher];
			//float lNorm = [sim lengthNorm: @"field" numberOfTerms: [[vector allTerms] count]];
			UKNotNil(vector);
			NSArray *vTerms = [vector allTerms];
			NSArray *freqs = [vector allTermFrequencies];
			int i;
			for (i = 0; i < [vTerms count]; i++)
			{
				if ([[term text] isEqualToString: [vTerms objectAtIndex: i]])
				{
					UKIntsEqual([[freqs objectAtIndex: i] intValue], freq);
				}
			}
		}
	}

	LCTerm *term = [[LCTerm alloc] initWithField: @"field" text: @"chocolate"];
	LCQuery *query = [[LCTermQuery alloc] initWithTerm: term];
	LCHits *hits = [knownSearcher search: query];
	UKIntsEqual(3, [hits count]);

	UKIntsEqual(2, [hits identifier: 0]);
	UKIntsEqual(3, [hits identifier: 1]);
	UKIntsEqual(0, [hits identifier: 2]);
	id <LCTermFrequencyVector> vector = [[knownSearcher indexReader] termFrequencyVector: [hits identifier: 1]
																		 field: @"field"];
	UKNotNil(vector);
	NSArray *terms = [vector allTerms];
	NSArray *freqs = [vector allTermFrequencies];
	UKNotNil(terms);
	UKIntsEqual(10, [terms count]);
	int i;
	for (i = 0; i < [terms count]; i++) {
		NSString *term = [terms objectAtIndex: i];
		int freq = [[freqs objectAtIndex: i] intValue];
		NSRange r = [test4 rangeOfString: term];
		UKTrue(r.location != NSNotFound);
		NSNumber *freqInt = [test4Map objectForKey: term];
		UKNotNil(freqInt);
		UKIntsEqual([freqInt intValue], freq);
	}
	[knownSearcher close];
}
  
@end
