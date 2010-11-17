#include "LCBooleanScorer.h"
#include "LCDisjunctionSumScorer.h"
#include "LCConjunctionScorer.h"
#include "LCReqExclScorer.h"
#include "LCReqOptSumScorer.h"
#include "LCDefaultSimilarity.h"
#include "LCNonMatchingScorer.h"
#include "GNUstep.h"

/* LuceneKit: This is actually BooleanScorer2 in lucene */
@interface LCCoordinator: NSObject
{ 
	int maxCoord;
	NSMutableArray *coordFactors;
	
	int nrMatchers; 
	LCBooleanScorer *scorer;
}
- (id) initWithScorer: (LCBooleanScorer *) scorer;
- (void) initiation; /* LuceneKit: init in lucene */
- (void) initiateDocument;
- (float) coordFactor; 
- (int) maxCoord;
- (void) setMaxCoord: (int) maxCoord;
- (int) nrMatchers;
- (void) setNrMatchers: (int) matchers;
@end

@interface LCBooleanDisjunctionSumScorer: LCDisjunctionSumScorer
{
	LCCoordinator *coordinator;
	int lastScoredDoc;
}
- (id) initWithSubScorers: (NSArray *) subScorers
		minimumNrMatchers: (int) minimumNrMatchers
			  coordinator: (LCCoordinator *) c;
@end

@interface LCBooleanConjunctionScorer: LCConjunctionScorer
{
	LCCoordinator *coordinator;
	int requiredNrMatchers;
	int lastScoredDoc;
}
- (id) initWithSimilarity: (LCSimilarity *) similarity
			  coordinator: (LCCoordinator *) c
       requiredNrMatchers: (int) required;
@end

@interface LCSingleMatchScorer: LCScorer
{
	LCScorer *scorer;
	LCCoordinator *coordinator;
	int lastScoredDoc;
}

- (id) initWithScorer: (LCScorer *) scorer
		  coordinator: (LCCoordinator *) coordinator;
@end

@interface LCBooleanScorer (LCPrivate)
- (void) initCountingSumScorer;
- (LCScorer *) countingDisjunctionSumScorer: (NSArray *) scorers
		minimumNumberShouldMatch: (int) min;
- (LCScorer *) countingConjunctionSumScorer: (NSArray *) requiredScorers;
- (LCScorer *) dualConjunctionSumScorer1: (LCScorer *) req1 scorer2: (LCScorer *) req2;
- (LCScorer *) makeCountingSumScorer;
- (LCScorer *) makeCountingSumScorerNoReq;
- (LCScorer *) makeCountingSumScorerSomeReq;
- (LCScorer *) addProhibitedScorers: (LCScorer *) requiredCountingSumScorer;
@end

@implementation LCBooleanScorer

- (id) initWithSimilarity: (LCSimilarity *) s
{
	return [self initWithSimilarity: s minimumNumberShouldMatch: 0];
}

- (id) initWithSimilarity: (LCSimilarity *) s
	minimumNumberShouldMatch: (int) min
{
	self = [super initWithSimilarity: s];
	if (min < 0) {
		NSLog(@"Error: minimum number of optional scorers should not be negative");
		return nil;
	}
	coordinator = [[LCCoordinator alloc] initWithScorer: self];
	minNrShouldMatch = min;
	requiredScorers = [[NSMutableArray alloc] init];
	optionalScorers = [[NSMutableArray alloc] init];
	prohibitedScorers = [[NSMutableArray alloc] init];
	countingSumScorer = nil;
	return self;
}

- (void) dealloc
{
  DESTROY(requiredScorers);
  DESTROY(optionalScorers);
  DESTROY(prohibitedScorers);
	
  DESTROY(coordinator);
  DESTROY(countingSumScorer);
  [super dealloc];
}

- (void) addScorer: (LCScorer *) scorer
		  required: (BOOL) required
		prohibited: (BOOL) prohibited
{
	if (!prohibited) {
		[coordinator setMaxCoord: [coordinator maxCoord] + 1];
	}
	
	if (required) {
		if (prohibited) {
			NSLog(@"Scorer cannot be required and prohibited");
		}
		[requiredScorers addObject: scorer];
	} else if (prohibited) {
		[prohibitedScorers addObject: scorer];
	} else {
		[optionalScorers addObject: scorer];
	}
}

- (void) initCountingSumScorer
{
	[coordinator initiation];
	ASSIGN(countingSumScorer, [self makeCountingSumScorer]);
}

- (LCScorer *) countingDisjunctionSumScorer: (NSArray *) scorers
		minimumNumberShouldMatch: (int) min
{
	return AUTORELEASE([[LCBooleanDisjunctionSumScorer alloc] initWithSubScorers: scorers
															   minimumNrMatchers: min
																	 coordinator: coordinator]);
}

- (LCScorer *) countingConjunctionSumScorer: (NSArray *) scorers
{
	int requiredNrMatchers = [scorers count];
	// LuceneKit: Why always use LCDefaultSimilarity ?
	LCBooleanConjunctionScorer *cs = [[LCBooleanConjunctionScorer alloc] initWithSimilarity: AUTORELEASE([[LCDefaultSimilarity alloc] init])
																				coordinator: coordinator
																		 requiredNrMatchers: requiredNrMatchers];
	NSEnumerator *e = [scorers objectEnumerator];
	LCScorer *scorer;
	while ((scorer = [e nextObject]))
	{
		[cs addScorer: scorer];
	}
	return AUTORELEASE(cs);
}

- (LCScorer *) dualConjunctionSumScorer1: (LCScorer *) req1 scorer2: (LCScorer *) req2
{
	//int requiredNrMatchers = [requiredScorers count];
	LCConjunctionScorer *cs = [[LCConjunctionScorer alloc] initWithSimilarity: similarity];
    // All scorers match, so defaultSimilarity super.score() always has 1 as
  	     // the coordination factor.
  	     // Therefore the sum of the scores of two scorers
  	     // is used as score.
	[cs addScorer: req1];
	[cs addScorer: req2];
	return AUTORELEASE(cs);
}

- (LCScorer *) makeCountingSumScorer
{
	if ([requiredScorers count] == 0)
		return [self makeCountingSumScorerNoReq];
	else
		return [self makeCountingSumScorerSomeReq];
}
- (LCScorer *) makeCountingSumScorerNoReq
{	// No required scorers
#if 0
	NSLog(@"LCBooleanScorer -makeCountingSumScorer");
	NSLog(@"requiredScorers %@", requiredScorers);
	NSLog(@"optionalScorers %@", optionalScorers);
	NSLog(@"prohibitedScorers %@", prohibitedScorers);
#endif
	if ([optionalScorers count] == 0) {
		return AUTORELEASE([[LCNonMatchingScorer alloc] init]); // no clauses or only prohibited scorers
	} else { // No required scorers. At least one optional scorer.
		// minNrShouldMatch optional scorers are quired, but at least 1
		int nrOptRequired = (minNrShouldMatch < 1) ? 1 : minNrShouldMatch;
		if ([optionalScorers count] < nrOptRequired) {
			return AUTORELEASE([[LCNonMatchingScorer alloc] init]); // fewer optional clauses tham minimum (at least 1) that should match
		} else { // optionalScorers.size() >= nrOptRequired, no required scorers
			LCScorer *requiredCountingSumScorer;
			if ([optionalScorers count] > nrOptRequired)
			{
				requiredCountingSumScorer = [self countingDisjunctionSumScorer: optionalScorers minimumNumberShouldMatch: nrOptRequired];
			}
			else
			{
				if ([optionalScorers count] == 1)
				{
					requiredCountingSumScorer = AUTORELEASE([[LCSingleMatchScorer alloc] initWithScorer: [optionalScorers objectAtIndex: 0] coordinator: coordinator]);
				}
				else
				{
					requiredCountingSumScorer = [self countingConjunctionSumScorer: optionalScorers];
				}
			}
			return [self addProhibitedScorers: requiredCountingSumScorer];	
		}
	}
}

- (LCScorer *) makeCountingSumScorerSomeReq
{ // At least one required scorer
#if 0
	NSLog(@"LCBooleanScorer -makeCountingSumScorerSomeReq");
	NSLog(@"minNrShouldMatch %d", minNrShouldMatch);
#endif
	if ([optionalScorers count] < minNrShouldMatch) {
		return AUTORELEASE([[LCNonMatchingScorer alloc] init]);
		// fewer optional clauses than minimum that should match
	} else if ([optionalScorers count] == minNrShouldMatch) {
		// all optional scorers also required.
          NSMutableArray *allReq = AUTORELEASE([[NSMutableArray alloc] init]);
		[allReq addObjectsFromArray: requiredScorers];
		[allReq addObjectsFromArray: optionalScorers];
		return [self addProhibitedScorers: [self countingConjunctionSumScorer: allReq]];
	} else {
		// optionalScorer.size() > minNrShouldMatch, and at least one required scorer
		LCScorer *requiredCountingSumScorer;
		if ([requiredScorers count] == 1)
		{
			requiredCountingSumScorer = [[LCSingleMatchScorer alloc] initWithScorer: [requiredScorers objectAtIndex: 0] coordinator: coordinator];
			AUTORELEASE(requiredCountingSumScorer);
		}
		else
		{
			requiredCountingSumScorer = [self countingConjunctionSumScorer: requiredScorers];
		}
		if (minNrShouldMatch > 0)
		{
			// use a required disjunction scorer over the optional scorers
			return [self addProhibitedScorers: [self dualConjunctionSumScorer1: requiredCountingSumScorer scorer2: [self countingDisjunctionSumScorer: optionalScorers minimumNumberShouldMatch: minNrShouldMatch]]];
		} else { // minNrShouldMatch == 0
			LCScorer *opt;
			if ([optionalScorers count] == 1)
			{
				opt = AUTORELEASE([[LCSingleMatchScorer alloc] initWithScorer: [optionalScorers objectAtIndex: 0] coordinator: coordinator]);
			}
			else
			{
				opt = [self countingDisjunctionSumScorer: optionalScorers minimumNumberShouldMatch: 1];
				// required 1 in combined, optional scorer.
			}
			LCReqOptSumScorer *r = [[LCReqOptSumScorer alloc] initWithRequired: [self addProhibitedScorers: requiredCountingSumScorer] optional: opt];
			return AUTORELEASE(r);
		}
	}
}

- (LCScorer *) addProhibitedScorers: (LCScorer *) requiredCountingSumScorer
{
	RETAIN(requiredCountingSumScorer);
	//NSLog(@"AddProhibitedScorers %@", requiredCountingSumScorer);
	if ([prohibitedScorers count] == 0)
	{
		return AUTORELEASE(requiredCountingSumScorer); // no prohibited
	}
	else
	{
		LCScorer *ex;
		if ([prohibitedScorers count] == 1)
		{
			ex = [prohibitedScorers objectAtIndex: 0];
		}
		else
		{
			ex = AUTORELEASE([[LCDisjunctionSumScorer alloc] initWithSubScorers: prohibitedScorers]);
		}
		return AUTORELEASE([[LCReqExclScorer alloc] initWithRequired: AUTORELEASE(requiredCountingSumScorer) excluded: ex]);
	}
}

- (void) score: (LCHitCollector *) hc
{
	if (countingSumScorer == nil) {
		[self initCountingSumScorer];
	}
	while ([countingSumScorer next]) {
		[hc collect: [countingSumScorer document] score: [self score]];
	}
}

- (BOOL) score: (LCHitCollector *) hc maximalDocument: (int) max
{
	int docNr = [countingSumScorer document];
	while (docNr < max) {
		[hc collect: docNr score: [self score]];
		if (![countingSumScorer next]) {
			return NO;
		}
		docNr = [countingSumScorer document];
	}
	return YES;
}

- (int) document { return [countingSumScorer document]; }

- (BOOL) next
{
	if (countingSumScorer == nil) {
		[self initCountingSumScorer];
	}
	return [countingSumScorer next];
}

- (float) score
{
	[coordinator initiateDocument];
	float sum = [countingSumScorer score];
	return (sum * [coordinator coordFactor]);
}

- (BOOL) skipTo: (int) target
{
	if (countingSumScorer == nil) {
		[self initCountingSumScorer];
	}
	return [countingSumScorer skipTo: target];
}

- (LCExplanation *) explain: (int) doc
{
	NSLog(@"not supported");
	return nil;
}

@end

@implementation LCBooleanConjunctionScorer 
- (id) initWithSimilarity: (LCSimilarity *) s
			  coordinator: (LCCoordinator *) c
       requiredNrMatchers: (int) required
{
	self = [super initWithSimilarity: s];
	ASSIGN(coordinator, c);
	requiredNrMatchers = required;
	lastScoredDoc = -1;
	return self;
}

- (void) dealloc
{
  DESTROY(coordinator);
  [super dealloc];
}

- (float) score
{
	if ([self document] > lastScoredDoc) {
		lastScoredDoc = [self document];
		[coordinator setNrMatchers: [coordinator nrMatchers] + requiredNrMatchers];
	}
	return [super score];
}
@end

@implementation LCBooleanDisjunctionSumScorer
- (id) initWithSubScorers: (NSArray *) sub
		minimumNrMatchers: (int) minimum
			  coordinator: (LCCoordinator *) c
{
	self = [super initWithSubScorers: sub
				   minimumNrMatchers: minimum];
	ASSIGN(coordinator, c);
	lastScoredDoc = -1;
	return self;
}

- (void) dealloc
{
  DESTROY(coordinator);
  [super dealloc];
}

- (float) score
{
	int t;
	if ([self document] > lastScoredDoc) {
		lastScoredDoc = [self document];
		t = [coordinator nrMatchers] + [super nrMatchers];
		[coordinator setNrMatchers: t];
	}
	return [super score];
}
@end

@implementation LCSingleMatchScorer
- (id) initWithScorer: (LCScorer *) s coordinator: (LCCoordinator *) c
{
	self = [self initWithSimilarity: [s similarity]];
	ASSIGN(scorer, s);
	ASSIGN(coordinator, c);
	lastScoredDoc = -1;
	return self;
}

- (void) dealloc
{
  DESTROY(coordinator);
  DESTROY(scorer);
  [super dealloc];
}

- (float) score
{
	if ([self document] > lastScoredDoc)
	{
		lastScoredDoc = [self document];
		[coordinator setNrMatchers: [coordinator nrMatchers] + 1];
	}
	return [scorer score];
}

- (int) document
{
	return [scorer document];
}

- (BOOL) next
{
	return [scorer next];
}

- (BOOL) skipTo: (int) target
{
	return [scorer skipTo: target];
}

- (LCExplanation *) explain: (int) document
{
	return [scorer explain: document];
}

@end

@implementation LCCoordinator
- (id) initWithScorer: (LCBooleanScorer *) s
{
	self = [self init];
	scorer = s; //Don't retain as s retain us
	maxCoord = 0;
	return self;
}

- (void) dealloc
{
  //Don't release scorer as we not retain it
  DESTROY(coordFactors);
  [super dealloc];
}

- (void) initiation
{
	coordFactors = [[NSMutableArray alloc] init];
	LCSimilarity *sim = [scorer similarity];
	int i;
	for (i = 0; i <= maxCoord; i++)
	{
		[coordFactors addObject: [NSNumber numberWithFloat: [sim coordination: i max: maxCoord]]];
	}
}

- (void) initiateDocument
{
	nrMatchers = 0;
}

- (float) coordFactor 
{ 
	return [[coordFactors objectAtIndex: nrMatchers] floatValue]; 
}

- (int) maxCoord { return maxCoord; }
- (void) setMaxCoord: (int) max { maxCoord = max; }
- (int) nrMatchers { return nrMatchers; }
- (void) setNrMatchers: (int) matchers { nrMatchers = matchers; }
@end
