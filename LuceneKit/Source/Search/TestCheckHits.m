#include "TestCheckHits.h"
#include "LCQuery.h"
#include "LCSearcher.h"
#include "LCHits.h"
#include <UnitKit/UnitKit.h>

@implementation TestCheckHits

+ (void) checkHits: (LCQuery *) query 
		  searcher: (LCSearcher *) searcher results: (NSArray *) results
{
	LCHits *hits = [searcher search: query];
	[TestCheckHits checkDocIds: hits results: results];
}

+ (void) checkDocIds: (LCHits *) hits results: (NSArray *) results
{
	UKIntsEqual([hits count], [results count]);
	int i;
	for (i = 0; i < [results count]; i++)
	{
		UKIntsEqual([hits identifier: i], [[results objectAtIndex: i] intValue]);
	}
}

+ (void) checkEqual: (LCQuery *) query hits1: (LCHits *) hits1
	hits2: (LCHits *) hits2
{
	UKIntsEqual([hits1 count], [hits2 count]);
	int i;
	for (i = 0; i < [hits1 count]; i++)
	{
		UKIntsEqual([hits1 identifier: i], [hits2 identifier: i]);
		UKFloatsEqual([hits1 score: i], [hits2 score: i], 0.000001f);
	}
}

+ (void) checkHitsQuery: (LCQuery *) query hits1: (LCHits *) hits1
	 hits2: (LCHits *) hits2 results: (NSArray *) results
{
	[TestCheckHits checkDocIds: hits1 results: results];
	[TestCheckHits checkDocIds: hits2 results: results];
	[TestCheckHits checkEqual: query hits1: hits1 hits2: hits2];
}

@end

