#include "LCDisjunctionSumScorer.h"
#include "LCPriorityQueue.h"
#include "GNUstep.h"

@interface LCScorerQueue: LCPriorityQueue
@end

@interface LCDisjunctionSumScorer (LCPrivate)
- (void) initScorerQueue;
@end

@implementation LCDisjunctionSumScorer
- (id) init
{
	self = [super init];
	scorerQueue = nil;
	currentDoc = -1;
	nrMatchers = -1;
	currentScore = -1;
	return self;
}

- (id) initWithSubScorers: (NSArray *) s
		minimumNrMatchers: (int) m
{
	self = [self initWithSimilarity: nil];
	nrScorers = [s count];
	if (m <= 0) {
		NSLog(@"Minimum nr of matchers must be positive");
		return nil;
	}
	if (nrScorers <= 1) {
		NSLog(@"There must be at least 2 subScorers");
		return nil;
	}
	minimumNrMatchers = m;
	ASSIGN(subScorers, s);
	return self;
}

- (id) initWithSubScorers: (NSArray *) sub
{
	return [self initWithSubScorers: sub
				  minimumNrMatchers: 1];
}

- (void) initScorerQueue
{
	NSEnumerator *si = [subScorers objectEnumerator];
	scorerQueue = [(LCScorerQueue *)[LCScorerQueue alloc] initWithSize: nrScorers];
	LCScorer *se;
	while ((se = [si nextObject])) {
		if ([se next]) { // doc() method will be used in scorerQueue
			[scorerQueue insert: se];
		}
	}
}

- (void) dealloc
{
	DESTROY(subScorers);
        DESTROY(scorerQueue);
	[super dealloc];
}

- (BOOL) next
{
	if (scorerQueue == nil) {
		[self initScorerQueue];
	}
	
	if ([scorerQueue size] < minimumNrMatchers) {
		return NO;
	} else {
		return [self advanceAfterCurrent];
	}
}

- (BOOL) advanceAfterCurrent
{
	do { // repeat until minimum nr of matchers
		LCScorer *top = [scorerQueue top];
		currentDoc = [top document];
		currentScore = [top score];
		nrMatchers = 1;
		do { // Until all subscorers are after currentDoc
			if ([top next]) {
				[scorerQueue adjustTop];
			} else {
				[scorerQueue pop];
				if ([scorerQueue size] < (minimumNrMatchers - nrMatchers)) {
					// Nor enough subscorers left for a match on this document,
					// and also no more chance of any further match.
					return NO;
				}
				if ([scorerQueue size] == 0) {
					break; // nothing more to advance, check for last match.
				}
			}
			top = [scorerQueue top];
			if ([top document] != currentDoc) {
				break; // All remaining subscorers are after currentDoc.
			} else {
				currentScore += [top score];
				nrMatchers++;
			}
		} while (1);
		
		if (nrMatchers >= minimumNrMatchers) {
			return YES;
		} else if ([scorerQueue size] < minimumNrMatchers) {
			return NO;
		}
	} while (1);
}

- (float) score { return currentScore; }
- (int) document { return currentDoc; }
- (int) nrMatchers { return nrMatchers; }

- (BOOL) skipTo: (int) target
{
	if (scorerQueue == nil) {
		[self initScorerQueue];
	}
	if ([scorerQueue size] < minimumNrMatchers) {
		return NO;
	}
	if (target <= currentDoc) {
		//target = currentDoc + 1;
		return YES;
	}
	do {
		LCScorer *top = [scorerQueue top];
		if ([top document] >= target) {
			return [self advanceAfterCurrent];
		} else if ([top skipTo: target]) {
			[scorerQueue adjustTop];
		} else {
			[scorerQueue pop];
			if ([scorerQueue size] < minimumNrMatchers) {
				return NO;
			}
		}
	} while (1);
}

- (LCExplanation *) explain: (int) doc
{
	LCExplanation *res = [[LCExplanation alloc] init];
	[res setRepresentation: [NSString stringWithFormat: @"At least %d of", minimumNrMatchers]];
	NSEnumerator *ssi = [subScorers objectEnumerator];
	LCScorer *sr;
	while ((sr = [ssi nextObject]))
	{
		[res addDetail: [sr explain: doc]];
	}
	return AUTORELEASE(res);
}

@end

@implementation LCScorerQueue
- (BOOL) lessThan: (id) o1 : (id) o2
{
	if ([(LCScorer *)o1 document] < [(LCScorer *)o2 document])
		return YES;
	else
		return NO;
}
@end
