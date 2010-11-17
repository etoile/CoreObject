#include "TestSegmentReader.h"
#include "LCSegmentInfo.h"
#include "LCField.h"
#include "LCTerm.h"
#include "LCTermEnum.h"
#include "LCSegmentTermEnum.h"
#include "GNUstep.h"
#include "LCSegmentReader.h"
#include "LCDocument.h"
#include "LCRAMDirectory.h"
#include "TestDocHelper.h"
#include "LCDefaultSimilarity.h"

@implementation TestSegmentReader

- (id) init
{
	self = [super init];
	dir = [[LCRAMDirectory alloc] init];
	testDoc = [[LCDocument alloc] init];
	[TestDocHelper setupDoc: testDoc];
	[TestDocHelper writeDirectory: dir doc: testDoc];
	//TODO: Setup the reader w/ multiple documents
	LCSegmentInfo *info = [[LCSegmentInfo alloc] initWithName: @"test" numberOfDocuments: 1 directory: dir];
	reader = RETAIN([LCSegmentReader segmentReaderWithInfo: info]);
	return self;
}

#if 1

- (void) testBasic
{
	UKNotNil(dir);
	UKNotNil(reader);
	UKTrue([[TestDocHelper nameValues] count] > 0);
	UKTrue([TestDocHelper numFields: testDoc] == [[TestDocHelper all] count]);
}

- (void) testDocument
{
	UKIntsEqual([reader numberOfDocuments], 1);
	UKTrue([reader maximalDocument] >= 1);
	LCDocument *result = [reader document: 0];
	UKNotNil(result);
	//There are 2 unstored fields on the document that are not preserved across writing
	UKIntsEqual([TestDocHelper numFields: result], [TestDocHelper numFields: testDoc]-[[TestDocHelper unstored] count]);
	
	NSEnumerator *fields = [result fieldEnumerator];
	LCField *field;
	while ((field = [fields nextObject]))
	{
		UKNotNil(field);
		UKNotNil([[TestDocHelper nameValues] objectForKey: [field name]]);
	}
}

- (void) testDelete
{
	LCDocument *docToDelete = [[LCDocument alloc] init];
	[TestDocHelper setupDoc: docToDelete];
	[TestDocHelper writeDirectory: dir segment: @"seg-to-delete" doc: docToDelete];
	LCSegmentInfo *info = [[LCSegmentInfo alloc] initWithName: @"seg-to-delete" numberOfDocuments: 1 directory: dir];
	
	LCSegmentReader *deleteReader = [LCSegmentReader segmentReaderWithInfo: info];
	UKNotNil(deleteReader);
	UKIntsEqual([deleteReader numberOfDocuments], 1);
	[deleteReader deleteDocument: 0];
	UKTrue([deleteReader isDeleted: 0]);
	UKTrue([deleteReader hasDeletions]);
	UKIntsEqual([deleteReader numberOfDocuments], 0);
#if 0
	try {
        Document test = deleteReader.document(0);
        assertTrue(false);
	} catch (IllegalArgumentException e) {
        assertTrue(true);
	}
} catch (IOException e) {
	e.printStackTrace();
	assertTrue(false);
}
#endif
  }    

- (void) testGetFieldNameVariations
{
	NSArray *result = [reader fieldNames: LCFieldOption_ALL];
	UKNotNil(result);
	UKIntsEqual([result count], [[TestDocHelper all] count]);
	NSEnumerator *e = [result objectEnumerator];
	NSString *s;
	while ((s = [e nextObject]))
	{
		UKNotNil([[TestDocHelper nameValues] objectForKey: s]);
		//  assertTrue(DocHelper.nameValues.containsKey(s) == true || s.equals(""));
	}
	
	result = [reader fieldNames: LCFieldOption_INDEXED];
	UKNotNil(result);
	UKIntsEqual([result count], [[TestDocHelper indexed] count]);
	e = [result objectEnumerator];
	while ((s = [e nextObject]))
	{
		UKNotNil([[TestDocHelper nameValues] objectForKey: s]);
    }
    
	result = [reader fieldNames: LCFieldOption_UNINDEXED];
	UKNotNil(result);
	UKIntsEqual([result count], [[TestDocHelper unindexed] count]);
	
    //Get all indexed fields that are storing term vectors
	result = [reader fieldNames: LCFieldOption_INDEXED_WITH_TERMVECTOR];
	UKNotNil(result);
	UKIntsEqual([result count], [[TestDocHelper termvector] count]);
	
	result = [reader fieldNames: LCFieldOption_INDEXED_NO_TERMVECTOR];
	UKNotNil(result);
	UKIntsEqual([result count], [[TestDocHelper notermvector] count]);
	
} 

- (void) testTerms
{
	
	LCSegmentTermEnumerator *terms = (LCSegmentTermEnumerator *)[reader termEnumerator];
	UKNotNil(terms);
	while([terms hasNextTerm])
	{
		LCTerm *term = [terms term];
		UKNotNil(term);
		NSString *fieldValue = [[TestDocHelper nameValues] objectForKey: [term field]];
		UKTrue([fieldValue rangeOfString: [term text]].location != NSNotFound);
		//     assertTrue(fieldValue.indexOf(term.text()) != -1);
	}
	
	id <LCTermDocuments> termDocs = [reader termDocuments];
	UKNotNil(termDocs);
	LCTerm *t = [[LCTerm alloc] initWithField: [TestDocHelper TEXT_FIELD_1_KEY] text: @"field"];
	[termDocs seekTerm: t];
	UKTrue([termDocs hasNextDocument]);

	t = [[LCTerm alloc] initWithField: [TestDocHelper NO_NORMS_KEY] text: [TestDocHelper NO_NORMS_TEXT]];
	[termDocs seekTerm: t];
	UKTrue([termDocs hasNextDocument]);
	
	id <LCTermPositions> positions = [reader termPositions];
	[positions seekTerm: t];
	UKNotNil(positions);
	UKIntsEqual([positions document], 0);
	UKTrue([positions nextPosition] >= 0);
}


- (void) testNorms
{
#if 0
public void testNorms() {
    //TODO: Not sure how these work/should be tested
	/*
	 try {
		 byte [] norms = reader.norms(DocHelper.TEXT_FIELD_1_KEY);
		 System.out.println("Norms: " + norms);
		 assertTrue(norms != null);
	 } catch (IOException e) {
		 e.printStackTrace();
		 assertTrue(false);
	 }
	 */
	
}
#endif

	[TestSegmentReader checkNorms: reader];
}
#endif

+ (void) checkNorms: (LCIndexReader *) reader
{
	int i;
	for (i = 0; i < [[TestDocHelper fields] count]; i++)
	{
		LCField *f = [[TestDocHelper fields] objectAtIndex: i];
		if ([f isIndexed]) {
			UKTrue([reader hasNorms: [f name]] == (![f omitNorms]));
			UKTrue([reader hasNorms: [f name]] == ([[TestDocHelper noNorms] objectForKey: [f name]] == nil));
			if (![reader hasNorms: [f name]]) {
				// test for fake norms of 1.0
				//NSLog(@"Test for fake norms");
				NSData *norms = [reader norms: [f name]];
				UKIntsEqual([norms length], [reader maximalDocument]);
				char b = [LCDefaultSimilarity encodeNorm: 1.0f];
				char *bytes = (char *)[norms bytes];

				int j;
				for (j = 0; j < [reader maximalDocument]; j++) {
					//NSLog(@"b = %d, byte = %d", b, *(bytes+j));
					UKTrue(*(bytes+j) == b);
				}
				NSMutableData *norms1 = [[NSMutableData alloc] init];
				[reader setNorms: [f name] bytes: norms1 offset: 0];
				bytes = (char *)[norms bytes];
				for (j = 0; j < [reader maximalDocument]; j++) {
					UKTrue(*(bytes+j) == b);
				}
			}
		}
	}
}
#if 0

- (void) testTermVectors
{
	id <LCTermFrequencyVector> result = [reader termFrequencyVector: 0 field: [TestDocHelper TEXT_FIELD_2_KEY]];
	UKNotNil(result);
	NSArray *terms = [result allTerms];
	NSArray *freqs = [result allTermFrequencies];
	UKNotNil(terms);
	UKIntsEqual([terms count], 3);
	UKNotNil(freqs);
	UKIntsEqual([freqs count], 3);
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		NSString *term = [terms objectAtIndex: i];
		long freq = [[freqs objectAtIndex: i] longValue];
		UKTrue([[TestDocHelper FIELD_2_TEXT] rangeOfString: term].location != NSNotFound);
		UKTrue(freq > 0);
	}
	NSArray *results = [reader termFrequencyVectors: 0];
	UKNotNil(result);
	UKIntsEqual([results count], 2);
}

#endif

@end
