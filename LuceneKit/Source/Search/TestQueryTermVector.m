#include <UnitKit/UnitKit.h>
#include <Foundation/Foundation.h>
#include "LCQueryTermVector.h"
#include "LCWhitespaceAnalyzer.h"

@interface TestQueryTermVector: NSObject <UKTest>
@end

@implementation TestQueryTermVector

- (void) checkGold: (NSArray *) terms gold: (NSArray *) gold freqs: (NSArray *) freqs goldFreqs: (NSArray *) goldFreqs
{
	int i;
	for (i = 0; i < [terms count]; i++)
	{
		UKStringsEqual([terms objectAtIndex: i], [gold objectAtIndex: i]);
		UKIntsEqual([[freqs objectAtIndex: i] intValue], [[goldFreqs objectAtIndex: i] intValue]);
	}
}

- (void) testConstructor
{
	NSArray *queryTerm = [NSArray arrayWithObjects: @"foo", @"bar", @"foo", @"again", @"foo", @"bar",
		@"go", @"go", @"go", nil];
	NSArray *gold = [NSArray arrayWithObjects: @"again", @"bar", @"foo", @"go", nil];
	NSArray *goldFreqs = [NSArray arrayWithObjects: @"1", @"2", @"3", @"3", nil];
	LCQueryTermVector *result = [[LCQueryTermVector alloc] initWithQueryTerms: queryTerm];
	UKNotNil(result);
	NSArray *terms = [result allTerms];
	UKIntsEqual(4, [terms count]);
	NSArray *freqs = [result allTermFrequencies];
	UKIntsEqual(4, [freqs count]);
	[self checkGold: terms gold: gold freqs: freqs goldFreqs: goldFreqs];
	result = [[LCQueryTermVector alloc] initWithQueryTerms: nil];
	UKIntsEqual(0, [[result allTerms] count]);
	
	result = [[LCQueryTermVector alloc] initWithString: @"foo bar foo again foo bar go go go"
											  analyzer: [[LCWhitespaceAnalyzer alloc] init]];
	UKNotNil(result);
	terms = [result allTerms];
	UKIntsEqual(4, [terms count]);
	freqs = [result allTermFrequencies];
	UKIntsEqual(4, [freqs count]);
	[self checkGold: terms gold: gold freqs: freqs goldFreqs: goldFreqs];
}

@end
