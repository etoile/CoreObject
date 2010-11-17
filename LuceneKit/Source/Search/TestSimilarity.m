#include <UnitKit/UnitKit.h>
#include "LCSimilarity.h"
#include "LCRAMDirectory.h"
#include "LCIndexWriter.h"
#include "LCSimpleAnalyzer.h"
#include "LCDocument.h"
#include "GNUstep.h"
#include "LCIndexSearcher.h"
#include "LCTermQuery.h"
#include "LCBooleanQuery.h"

@interface TestSimilarity: NSObject <UKTest>
@end

@interface LCSimpleSimilarity: LCSimilarity
@end

@implementation TestSimilarity
- (void) collect1: (int) doc score: (float) score
{
	UKTrue(score == 1.0f);
}

- (void) collect2: (int) doc score: (float) score
{
	UKTrue(score == (float)doc+1);
}

- (void) testSimilarity
{
	LCRAMDirectory *store = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory:store analyzer:[[LCSimpleAnalyzer alloc] init]
															  create:YES];
	[writer setSimilarity: [[LCSimpleSimilarity alloc] init]];
	
	NSLog(@"Write first document");
	LCDocument *d1 = [[LCDocument alloc] init];
	LCField *field = [[LCField alloc] initWithName:@"field" string: @"a c" store:LCStore_YES index:LCIndex_Tokenized];
	[d1 addField: field];
	DESTROY(field);
	
	NSLog(@"Write second document");
	LCDocument *d2 = [[LCDocument alloc] init];
	field = [[LCField alloc] initWithName:@"field" string: @"a b c" store:LCStore_YES index:LCIndex_Tokenized];
	[d2 addField: field];
	DESTROY(field);
	
	[writer addDocument: d1];
	[writer addDocument: d2];
	NSLog(@"optimize");
	[writer optimize];
	[writer close];
	
	LCSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: store];
	[searcher setSimilarity: [[LCSimpleSimilarity alloc] init]];
	
	LCTerm *a = [[LCTerm alloc] initWithField: @"field"  text: @"a"];
	LCTerm *b = [[LCTerm alloc] initWithField: @"field"  text: @"b"];
	LCTerm *c = [[LCTerm alloc] initWithField: @"field"  text: @"c"];
	
	LCHitCollector *hc = [[LCHitCollector alloc] init];
	[hc setTarget: self];
	[hc setSelector: @selector(collect1:score:)];
	NSLog(@"search");
	LCTermQuery *query = [[LCTermQuery alloc] initWithTerm: b];
	[searcher search: query hitCollector: hc];
	
#if 0
	LCBooleanQuery *bq = [[LCBooleanQuery alloc] init];
	[bq addQuery: [[LCTermQuery alloc] initWithTerm: a] occur: LCOccur_SHOULD];
	[bq addQuery: [[LCTermQuery alloc] initWithTerm: b] occur: LCOccur_SHOULD];
	[hc setTarget: self];
	[hc setSelector: @selector(collect2:score:)];
	[searcher search: bq hitCollector: hc];
	
#endif
#if 0
    PhraseQuery pq = new PhraseQuery();
    pq.add(a);
    pq.add(c);
    //System.out.println(pq.toString("field"));
    searcher.search
		(pq,
		 new HitCollector() {
			 public final void collect(int doc, float score) {
				 //System.out.println("Doc=" + doc + " score=" + score);
				 assertTrue(score == 1.0f);
			 }
		 });
	
    pq.setSlop(2);
    //System.out.println(pq.toString("field"));
    searcher.search
		(pq,
		 new HitCollector() {
			 public final void collect(int doc, float score) {
				 //System.out.println("Doc=" + doc + " score=" + score);
				 assertTrue(score == 2.0f);
			 }
		 });
}
#endif
}

	

@end

@implementation LCSimpleSimilarity
- (float) lengthNorm: (NSString *) fieldName numberOfTerms: (int) numTerms { return 1.0f; }
- (float) queryNorm: (float) sumOfSquredWeights { return 1.0f; }
- (float) termFrequencyWithFloat: (float) freq { return freq; }
- (float) sloppyFrequency: (int) distance { return 2.0f; }
- (float) inverseDocumentFrequencyWithTerm: (LCTerm *) term
								  searcher: (LCSearcher *) searcher
{ return 1.0f; }
- (float) inverseDocumentFrequencyWithTerms: (NSArray *) terms
								   searcher: (LCSearcher *) searcher
{ return 1.0f; }
- (float) coordination: (int) overlap max: (int) maxOverlap { return 1.0f; }
@end
