#include "LCConjunctionScorer.h"
#include "GNUstep.h"

@interface LCScorer (LCCompare_Document)
- (NSComparisonResult) compareDocument: (LCScorer *) other;
@end

@implementation LCScorer (LCCompare_Document)
- (NSComparisonResult) compareDocument: (LCScorer *) other
{
	if ([self document] < [other document]) return NSOrderedAscending;
	else if ([self document] > [other document]) return NSOrderedDescending;
	else return NSOrderedSame;
}
@end

@interface LCConjunctionScorer (LCPrivate)
- (LCScorer *) first;
- (LCScorer *) last;
- (BOOL) doNext;
- (void) initWithScorers: (BOOL) initScorers;
- (void) sortScorers;
@end

@implementation LCConjunctionScorer
- (id) initWithSimilarity: (LCSimilarity *) s
{
	self = [super initWithSimilarity: s];
	scorers = [[NSMutableArray alloc] init];
	firstTime = YES;
	more = YES;
	return self;
}

- (void) dealloc
{
	DESTROY(scorers);
	[super dealloc];
}

- (void) addScorer: (LCScorer *) scorer
{
	[scorers addObject: scorer];
}

- (LCScorer *) first 
{
	if ([scorers count])
		return [scorers objectAtIndex: 0]; 
	else
		return nil;
}

- (LCScorer *) last
{
	if ([scorers count])
		return [scorers lastObject]; 
	else
		return nil;
}

- (int) document
{
	return [[self first] document];
}

- (BOOL) next
{
	if (firstTime) {
		[self initWithScorers: YES];
	} else if (more) {
		more = [[self last] next]; // trigger further scanning
	}
	return [self doNext];
}

- (BOOL) doNext
{
	while (more && ([[self first] document] < [[self last] document])) // find doc w/ all clauses
	{
		more = [[self first] skipTo: [[self last] document]]; // skip first upto last
		[scorers addObject: [scorers objectAtIndex: 0]]; // move first to last
		[scorers removeObjectAtIndex: 0]; 
	}
	return more; // found a doc with all clauses
}

- (BOOL) skipTo: (int) target
{
	if (firstTime) {
		[self initWithScorers: NO];
	}
	
	NSEnumerator *e = [scorers objectEnumerator];
	LCScorer *scorer = [e nextObject];;
	while (more && (scorer != nil))
	{
		more = [scorer skipTo: target];
		scorer = [e nextObject];
	}
	
	if (more) [self sortScorers]; // re-sort scorers
	
	return [self doNext];
}

- (float) score
{
	float score = 0.0f; // sum scores
	NSEnumerator *e = [scorers objectEnumerator];
	LCScorer *scorer;
	while ((scorer = [e nextObject]))
	{
		score += [scorer score];
	}
	score *= coord;
	return score;
}

- (void) initWithScorers: (BOOL) initScorers
{
	coord = [[self similarity] coordination: [scorers count]
										max: [scorers count]];
	more = ([scorers count] > 0) ? YES : NO;
	
	if (initScorers) {
		// move each scorer to its first entry
		NSEnumerator *e = [scorers objectEnumerator];
		LCScorer *scorer = [e nextObject];
		while (more && (scorer != nil))
		{
			more = [scorer next];
			scorer = [e nextObject];
		}
		if (more)
			[self sortScorers]; // initial sort of list
	}
	
	firstTime = NO;
}

- (void) sortScorers
{
	[scorers sortUsingSelector: @selector(compareDocument:)];
}

- (LCExplanation *) explain: (int) doc
{
	NSLog(@"LCConjunctionScorer: Not supported");
	return nil;
}
@end
