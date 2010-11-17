#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCRAMDirectory.h"
#include "LCIndexWriter.h"
#include "LCIndexReader.h"
#include "LCSimpleAnalyzer.h"
#include "LCTermQuery.h"
#include "LCHitCollector.h"
#include "LCIndexSearcher.h"

@interface TestSetNorm: NSObject <UKTest>
{
	float scores[4];
}
@end


@implementation TestSetNorm

- (void) collect: (int) doc score: (float) score
{
	NSLog(@"doc %d, score %f", doc, score);
	scores[doc] = score;
}

- (void) testSetNorm
{
	LCRAMDirectory *store = [[LCRAMDirectory alloc] init];
	LCIndexWriter *writer = [[LCIndexWriter alloc] initWithDirectory: store 
															analyzer: [[LCSimpleAnalyzer alloc] init]
															  create: YES];
	
	LCField *fi = [[LCField alloc] initWithName: @"field" string: @"word" store: LCStore_YES index: LCIndex_Tokenized];
	LCDocument *d1 = [[LCDocument alloc] init];
	[d1 addField: fi];
	[writer addDocument: d1];
	[writer addDocument: d1];
	[writer addDocument: d1];
	[writer addDocument: d1];
	[writer close];
	
	// reset the boost of each instance of this document
	LCIndexReader *reader = [LCIndexReader openDirectory: store];
	[reader setNorm: 0 field: @"field" floatValue: 1.0f];
	[reader setNorm: 1 field: @"field" floatValue: 2.0f];
	[reader setNorm: 2 field: @"field" floatValue: 4.0f];
	[reader setNorm: 3 field: @"field" floatValue: 16.0f];
	[reader close];
	
	// check that searches are ordered by this boost
	LCTermQuery *query = [[LCTermQuery alloc] initWithTerm: [[LCTerm alloc] initWithField: @"field" text: @"word"]];
	LCHitCollector *hc = [[LCHitCollector alloc] init];
	[hc setTarget: self];
	[hc setSelector: @selector(collect:score:)];
	LCIndexSearcher *searcher = [[LCIndexSearcher alloc] initWithDirectory: store];
	[searcher search: query hitCollector: hc];
    
    float lastScore = 0.0f;
	int i;
	
    for (i = 0; i < 4; i++) {
		UKTrue(scores[i] > lastScore);
		lastScore = scores[i];
	}
}

@end

