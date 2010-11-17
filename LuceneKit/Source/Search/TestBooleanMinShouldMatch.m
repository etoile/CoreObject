#include <Foundation/Foundation.h>
#include <UnitKit/UnitKit.h>
#include "LCDirectory.h"
#include "LCQuery.h"
#include "LCBooleanQuery.h"
#include "LCIndexSearcher.h"
#include "LCIndexWriter.h"
#include "LCTermQuery.h"
#include "LCTerm.h"
#include "LCRAMDirectory.h"
#include "LCWhitespaceAnalyzer.h"
#include "GNUstep.h"

@interface TestBooleanMinShouldMatch: NSObject <UKTest>
{
	id <LCDirectory> index;
	LCIndexReader *r;
	LCIndexSearcher *s;
}
@end

@implementation TestBooleanMinShouldMatch

- (id)init
{
	self = [super init];

	NSArray *data = [NSArray arrayWithObjects:
	
            @"A 1 2 3 4 5 6",
            @"Z       4 5 6",
            [NSNull null],
            @"B   2   4 5 6",
            @"Y     3   5 6",
            [NSNull null],
            @"C     3     6",
            @"X       4 5 6",
	    nil];

	index = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: index
			analyzer: [[LCWhitespaceAnalyzer alloc] init]
			create: YES];

	int i;
	for (i = 0; i < [data count]; i++) {
	 	LCDocument *doc = [[LCDocument alloc] init];
		LCField *f = [[LCField alloc] initWithName: @"id"
				string: [NSString stringWithFormat: @"%d", i]
				store: LCStore_YES
				index: LCIndex_Untokenized
		   	   termVector: LCTermVector_NO];
		[doc addField: AUTORELEASE(f)];
		f = [[LCField alloc] initWithName: @"all"
				string: @"all"
				store: LCStore_YES
				index: LCIndex_Untokenized
		   	   termVector: LCTermVector_NO];
		[doc addField: AUTORELEASE(f)];
		if (![[data objectAtIndex: i] isKindOfClass: [NSNull class]])
		{
			f = [[LCField alloc] initWithName: @"data"
				string: [data objectAtIndex: i]
				store: LCStore_YES
				index: LCIndex_Tokenized
		   	   termVector: LCTermVector_NO];
			[doc addField: AUTORELEASE(f)];
		}
		[writer addDocument: AUTORELEASE(doc)];
	}

	[writer optimize];
	[writer close];

	ASSIGN(r, [LCIndexReader openDirectory: index]);
	s = [[LCIndexSearcher alloc] initWithDirectory: index];

	return self;
}

- (void) verifyNrHits: (LCQuery *) q :(int) expected
{
	LCHits *h = [s search: q];
	UKIntsEqual([h count], expected);
}

- (void) testAllOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];
	int i;
	for (i = 1; i <= 4; i++) {
		LCTerm *t = [[LCTerm alloc] initWithField: @"data"
			text: [NSString stringWithFormat: @"%d", i]];
		LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
		[q addQuery: tq occur: LCOccur_SHOULD];
	}
	[q setMinimumNumberShouldMatch: 2]; // match at least two of 4
	[self verifyNrHits: q : 2];
}

- (void) testOneReqAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 2]; 
	[self verifyNrHits: q : 5];
}

- (void) testSomeReqAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 2];
	[self verifyNrHits: q : 5];
}

- (void) testOneProhibAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 2]; 
	[self verifyNrHits: q : 1];
}

- (void) testSomeProhibAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"C"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 2]; 
	[self verifyNrHits: q : 1];
}

- (void) testOneReqOneProhibAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 3]; 
	[self verifyNrHits: q : 1];
}

- (void) testSomeReqOneProhibAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 3]; 
	[self verifyNrHits: q : 1];
}

- (void) testOneReqSomeProhibAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"C"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 3]; 
	[self verifyNrHits: q : 1];
}

- (void) testSomeReqSomeProhibAndSomeOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);


	t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);
	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"C"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 3]; 
	[self verifyNrHits: q : 1];
}

- (void) testMinHigherThenNumOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);


	t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);
	t = [[LCTerm alloc] initWithField: @"data" text: @"5"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"4"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"1"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"C"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST_NOT];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 90]; 
	[self verifyNrHits: q : 0];
}

- (void) testMinEqualToNumOptional
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"6"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 2]; 
	[self verifyNrHits: q : 1];
}

- (void) testOneOptionalEqualToMin
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"3"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_SHOULD];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 1]; 
	[self verifyNrHits: q : 1];
}

- (void) testNoOptionalButMin
{
	LCBooleanQuery *q = [[LCBooleanQuery alloc] init];

	LCTerm *t = [[LCTerm alloc] initWithField: @"all" text: @"all"];
	LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	t = [[LCTerm alloc] initWithField: @"data" text: @"2"];
	tq = [[LCTermQuery alloc] initWithTerm: t];
	[q addQuery: tq occur: LCOccur_MUST];
	AUTORELEASE(t);
	AUTORELEASE(tq);

	[q setMinimumNumberShouldMatch: 1]; 
	[self verifyNrHits: q : 0];
}
#if 0
    public void testRandomQueries() throws Exception {
      final Random rnd = new Random(0);

      String field="data";
      String[] vals = {"1","2","3","4","5","6","A","Z","B","Y","Z","X","foo"};
      int maxLev=4;

      // callback object to set a random setMinimumNumberShouldMatch
      TestBoolean2.Callback minNrCB = new TestBoolean2.Callback() {
        public void postCreate(BooleanQuery q) {
          BooleanClause[] c =q.getClauses();
          int opt=0;
          for (int i=0; i<c.length;i++) {
            if (c[i].getOccur() == BooleanClause.Occur.SHOULD) opt++;
          }
          q.setMinimumNumberShouldMatch(rnd.nextInt(opt+2));
        }
      };


      int tot=0;
      // increase number of iterations for more complete testing      
      for (int i=0; i<1000; i++) {
        int lev = rnd.nextInt(maxLev);
        BooleanQuery q1 = TestBoolean2.randBoolQuery(new Random(i), lev, field, vals, null);
        // BooleanQuery q2 = TestBoolean2.randBoolQuery(new Random(i), lev, field, vals, minNrCB);
        BooleanQuery q2 = TestBoolean2.randBoolQuery(new Random(i), lev, field, vals, null);
        // only set minimumNumberShouldMatch on the top level query since setting
        // at a lower level can change the score.
        minNrCB.postCreate(q2);

        // Can't use Hits because normalized scores will mess things
        // up.  The non-sorting version of search() that returns TopDocs
        // will not normalize scores.
        TopDocs top1 = s.search(q1,null,100);
        TopDocs top2 = s.search(q2,null,100);
        tot+=top2.totalHits;

        // The constrained query
        // should be a superset to the unconstrained query.
        if (top2.totalHits > top1.totalHits) {
          TestCase.fail("Constrained results not a subset:\n"
                + CheckHits.topdocsString(top1,0,0)
                + CheckHits.topdocsString(top2,0,0)
                + "for query:" + q2.toString());
        }

        for (int hit=0; hit<top2.totalHits; hit++) {
          int id = top2.scoreDocs[hit].doc;
          float score = top2.scoreDocs[hit].score;
          boolean found=false;
          // find this doc in other hits
          for (int other=0; other<top1.totalHits; other++) {
            if (top1.scoreDocs[other].doc == id) {
              found=true;
              float otherScore = top1.scoreDocs[other].score;
              // check if scores match
              if (Math.abs(otherScore-score)>1.0e-6f) {
                        TestCase.fail("Doc " + id + " scores don't match\n"
                + CheckHits.topdocsString(top1,0,0)
                + CheckHits.topdocsString(top2,0,0)
                + "for query:" + q2.toString());
              }
            }
          }

          // check if subset
          if (!found) TestCase.fail("Doc " + id + " not found\n"
                + CheckHits.topdocsString(top1,0,0)
                + CheckHits.topdocsString(top2,0,0)
                + "for query:" + q2.toString());
        }
      }
      // System.out.println("Total hits:"+tot);
    }

}

#endif

@end
