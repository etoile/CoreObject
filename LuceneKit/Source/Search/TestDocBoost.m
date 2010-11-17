#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCSimpleAnalyzer.h"
#include "LCRAMDirectory.h"
#include "LCIndexWriter.h"
#include "LCTerm.h"
#include "LCDocument.h"
#include "LCTermQuery.h"
#include "LCIndexSearcher.h"

@interface TestDocBoost: NSObject <UKTest>
{
	float scores[4];
}
@end

@implementation TestDocBoost

- (void) collect: (int) doc score: (float) score
{
	scores[doc] = score;
}

- (void) testDocBoost
{
	LCRAMDirectory *store = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: store 
															analyzer: [[LCSimpleAnalyzer alloc] init] create: YES];
	LCField *f1 = [[LCField alloc] initWithName: @"field"
										 string: @"word"
										  store: LCStore_YES
										  index: LCIndex_Tokenized];
	LCField *f2 = [[LCField alloc] initWithName: @"field"
										 string: @"word"
										  store: LCStore_YES
										  index: LCIndex_Tokenized];
	[f2 setBoost: 2.0f];
	
	LCDocument *d1 = [[LCDocument alloc] init];
	LCDocument *d2 = [[LCDocument alloc] init];
	LCDocument *d3 = [[LCDocument alloc] init];
	LCDocument *d4 = [[LCDocument alloc] init];
	
	[d3 setBoost: 3.0f];
	[d4 setBoost: 4.0f];
	
	[d1 addField: f1]; // boost = 1
	[d2 addField: f2]; // boost = 2
	[d3 addField: f1]; // boost = 3
	[d4 addField: f2]; // boost = 4
	
	[writer addDocument: d1];
	[writer addDocument: d2];
	[writer addDocument: d3];
	[writer addDocument: d4];
	[writer optimize];
	[writer close];
	
	LCTerm *term = [[LCTerm alloc] initWithField: @"field" text: @"word"];
	LCTermQuery *query = [[LCTermQuery alloc] initWithTerm: term];
	LCHitCollector *hc = [[LCHitCollector alloc] init];
	[hc setTarget: self];
	[hc setSelector: @selector(collect:score:)];
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: store];
	[searcher search: query hitCollector: hc];
			
	float lastScore = 0.0f;
	int i;
		
	for ( i = 0; i < 4; i++) {
		UKTrue(scores[i] > lastScore);
		lastScore = scores[i];
	}
}
	

@end
