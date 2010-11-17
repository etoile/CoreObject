#include "LCReqExclScorer.h"
#include "LCExplanation.h"
#include "GNUstep.h"

@interface LCReqExclScorer (LCPrivate)
- (BOOL) toNonExcluded;
@end

@implementation LCReqExclScorer

- (id) initWithRequired: (LCScorer *) r excluded: (LCScorer *) e
{
	self = [self initWithSimilarity: nil]; // No similarity used
	ASSIGN(reqScorer, r);
	ASSIGN(exclScorer, e);
	firstTime = YES;
	return self;
}

- (void) dealloc
{
	DESTROY(reqScorer);
	DESTROY(exclScorer);
	[super dealloc];
}

- (BOOL) next
{
	if (firstTime)
	{
		if (![exclScorer next]) {
			DESTROY(exclScorer); // exhausted at start
		}
		firstTime = NO;
	}
	if (reqScorer == nil) return NO;
	if (![reqScorer next]) {
		DESTROY(reqScorer); // exhausted, nothing left
		return NO;
	}
	if (exclScorer == nil) {
		return YES; // reqScorer.next() already returned true
	}
	return [self toNonExcluded];
}

- (BOOL) toNonExcluded
{
	int exclDoc = [exclScorer document];
	do {
		int reqDoc = [reqScorer document]; // may be excluded
		if (reqDoc < exclDoc) {
			return YES; // reqScorer advanced to before exclScorer, ie. not excluded
		} else if (reqDoc > exclDoc) {
			if (! [exclScorer skipTo: reqDoc]) {
				DESTROY(exclScorer); // exhausted, no more exclusions
				return YES;
			}
			exclDoc = [exclScorer document];
			if (exclDoc > reqDoc) {
				return YES; // not excluded
			}
		}
	} while ([reqScorer next]);
	DESTROY(reqScorer); // exhausted, nothing left
	return NO;
}

- (int) document
{
	return [reqScorer document]; // reqScorer may be null when next() or skipTo() already return flase
}

- (float) score
{
	return [reqScorer score]; // reqScorer may be null when next() or skipTo() already return flase
}

- (BOOL) skipTo: (int) target
{
	if (firstTime) {
		firstTime = NO;
		if (![exclScorer skipTo: target]) {
			DESTROY(exclScorer);
		}
	}
	if (reqScorer == nil) {
		return NO;
	}
	if (exclScorer == nil) {
		return [reqScorer skipTo: target];
	}
	if (![reqScorer skipTo: target]) {
		DESTROY(reqScorer);
		return NO;
	}
	return [self toNonExcluded];
}

- (LCExplanation *) explain: (int) doc
{
	LCExplanation *res = [[LCExplanation alloc] init];
	if ([exclScorer skipTo: doc] && ([exclScorer document] == doc)) {
		[res setRepresentation: @"excluded"];
	} else {
		[res setRepresentation: @"not excluded"];
		[res addDetail: [reqScorer explain: doc]];
	}
	return AUTORELEASE(res);
}

@end
