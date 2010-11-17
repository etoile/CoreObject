#include <Foundation/Foundation.h>

@class LCQuery;
@class LCSearcher;
@class LCHits;

@interface TestCheckHits: NSObject
+ (void) checkHits: (LCQuery *) query
	  searcher: (LCSearcher *) searcher results: (NSArray *) results;

+ (void) checkDocIds: (LCHits *) hits results: (NSArray *) results;

+ (void) checkEqual: (LCQuery *) query hits1: (LCHits *) hits1
        hits2: (LCHits *) hits2;

+ (void) checkHitsQuery: (LCQuery *) query hits1: (LCHits *) hits1
         hits2: (LCHits *) hits2 results: (NSArray *) results;

@end
