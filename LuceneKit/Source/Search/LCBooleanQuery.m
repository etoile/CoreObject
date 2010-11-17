#include "LCBooleanQuery.h"
#include "LCSimilarityDelegator.h"
#include "LCSearcher.h"
#include "LCBooleanScorer.h"
#include "LCWeight.h"
#include "LCSmallFloat.h"
#include "NSString+Additions.h"
#include "GNUstep.h"

/* LuceneKit: this is actually BooleanWeight2 in lucene */
@interface LCBooleanWeight: NSObject <LCWeight>
{
	LCSimilarity *similarity;
	LCBooleanQuery *query;
	NSMutableArray *weights;
	
	int minNrShouldMatch;
}

- (id) initWithSearcher: (LCSearcher *) searcher
	minimumNumberShouldMatch: (int) min
                  query: (LCBooleanQuery *) query;
@end


@interface LCBooleanSimilarityDelegator: LCSimilarityDelegator
@end

@implementation LCBooleanSimilarityDelegator
- (float) coordination: (int) overlap max: (int) maxOverlap
{
	return 1.0f;
}
@end

static int maxClauseCount = 1024;

@implementation LCBooleanQuery
+ (int) maxClauseCount { return maxClauseCount; }
+ (void) setMaxClauseCount: (int) max 
{ 
	if (max < 1)
	{
		NSLog(@"Error: maxClauseCount must be >= 1");
	}
	else
		maxClauseCount = max; 
}
- (id) init
{
	self = [super init];
	clauses = [[NSMutableArray alloc] init];
	minNrShouldMatch = 0;
	return self;
}
- (id) initWithCoordination: (BOOL) dc
{
	self = [self init];
	disableCoord = dc;
	return self;
}

- (void) dealloc
{
	DESTROY(clauses);
	[super dealloc];
}

- (BOOL) isCoordinationDisabled { return disableCoord; }
- (void) setCoordinationDisabled: (BOOL) disable { disableCoord = disable; }
- (LCSimilarity *) similarity: (LCSearcher *) searcher
{
	LCSimilarity *result = [super similarity: searcher];
	if (disableCoord) { // disable coord as requested
		result = [[LCBooleanSimilarityDelegator alloc] init];
		AUTORELEASE(result);
	}
	return result;
}

- (void) addQuery: (LCQuery *) query
			occur: (LCOccurType) occur
{
	LCBooleanClause *clause = [[LCBooleanClause alloc] initWithQuery: query occur: occur];
	[self addClause: clause];
	DESTROY(clause);
}

- (void) addClause: (LCBooleanClause *) clause
{
	if ([clauses count] >= maxClauseCount)
	{
		NSLog(@"Too many clauses");
		return;
	}
	[clauses addObject: clause];
}

- (NSArray *) clauses
{
	return clauses;
}

- (void) setClauses: (NSArray *) c
{
	[clauses setArray: c];
}

- (id <LCWeight>) createWeight: (LCSearcher *) searcher
{
	return AUTORELEASE([[LCBooleanWeight alloc] initWithSearcher: searcher minimumNumberShouldMatch: minNrShouldMatch query: self]);
}

- (LCQuery *) rewrite: (LCIndexReader *) reader
{
	if ([clauses count] == 1) { // optimize 1-clause queries
		LCBooleanClause *c = [clauses objectAtIndex: 0];
		if ([c isProhibited]) { // just return clause
			LCQuery *query = [[c query] rewrite: reader]; // rewrite first
			if ([self boost] != 1.0f) {// incorporate boost
				if ([query isEqual: [c query]]) // if rewrite was no-op
					query = [query copy];
				[query setBoost: [self boost] * [query boost]];
			}
			return query;
		}
	}
	
	LCBooleanQuery *clone = nil; // recursively rewrite
	int i;
	for (i = 0; i < [clauses count]; i++) {
		LCBooleanClause *c = [clauses objectAtIndex: i];
		LCQuery *query = [[c query] rewrite: reader];
		if ([query isEqual: [c query]] == NO) { // clause rewrote: must clone
			if (clone == nil)
				clone = [self copy];
			LCBooleanClause *clause = [[LCBooleanClause alloc] initWithQuery: query occur: [c occur]];
			[clone replaceClauseAtIndex: i withClause: AUTORELEASE(clause)];
		}
	}
	if (clone != nil) {
		return clone; // some clauses rewrote
	} else {
		return self; // no clauses rewrote
	}
}

- (void) extractTerms: (NSMutableArray *) terms
{
	NSEnumerator *e = [clauses objectEnumerator];
	LCBooleanClause *clause;
	while ((clause = [e nextObject])) {
		[[clause query] extractTerms: terms];
	}
}

- (id) copyWithZone: (NSZone *) zone
{
	LCBooleanQuery *clone = [super copyWithZone: zone];
	[clone setClauses: AUTORELEASE([[self clauses] copy])];
	return clone;
}

- (void) replaceClauseAtIndex: (int) index 
				   withClause: (LCBooleanClause *) clause
{
	[clauses replaceObjectAtIndex: index withObject: clause];
}

- (NSString *) descriptionWithField: (NSString *) field
{
	NSMutableString *s = [[NSMutableString alloc] init];
	BOOL needParens = (([self boost] != 1.0) || ([self minimumNumberShouldMatch] > 0));
	if (needParens) {
		[s appendString: @"("];
	}
	int i;
	for (i = 0; i < [clauses count]; i++) {
		LCBooleanClause *c = [clauses objectAtIndex: i];
		if ([c isProhibited])
			[s appendString: @"-"];
		else if ([c isRequired])
			[s appendString: @"+"];
		
		LCQuery *subQuery = [c query];
		if ([subQuery isKindOfClass: [LCBooleanQuery class]]) { // wrap sub-bools is parens
			[s appendString: @"("];
			[s appendString: [[c query] descriptionWithField: field]];
			[s appendString: @")"];
		} else
			[s appendString: [[c query] descriptionWithField: field]];
		
		if (i != [clauses count]-1)
			[s appendString: @" "];
	}

	if (needParens) {
		[s appendFormat: @")"];
	}
	if ([self minimumNumberShouldMatch] > 0) {
		[s appendFormat: @"~%d", [self minimumNumberShouldMatch]];
	}

	if ([self boost] != 1.0f)
	{
		[s appendFormat: @"%@", LCStringFromBoost([self boost])];
	}
	
	return AUTORELEASE(s);
}

- (BOOL) isEqual: (id) o
{
	if (![o isKindOfClass: [LCBooleanQuery class]])
		return NO;
	LCBooleanQuery *other = (LCBooleanQuery *)o;
	if (([self boost] == [other boost]) &&
		([clauses isEqualToArray: [other clauses]]) &&
		([self minimumNumberShouldMatch] == [other minimumNumberShouldMatch]))
		return YES;
	else
		return NO;
}

- (NSUInteger) hash
{
	return (unsigned)((FloatToIntBits([self boost]) ^ [clauses hash]) + [self minimumNumberShouldMatch]);
}

/**
 * Specifies a minimum number of the optional BooleanClauses
 * which must be satisifed.
 *
 * <p>
 * By default no optional clauses are neccessary for a match
 * (unless there are no required clauses).  If this method is used,
 * then the specified numebr of clauses is required.
 * </p>
 * <p>
 * Use of this method is totally independant of specifying that
 * any specific clauses are required (or prohibited).  This number will
 * only be compared against the number of matching optional clauses.
 * </p>
 * <p>
 * EXPERT NOTE: Using this method will force the use of BooleanWeight2,
 * regardless of wether setUseScorer14(true) has been called.
 * </p>
 *
 * @param min the number of optional clauses that must match
 * @see #setUseScorer14
 */
- (void) setMinimumNumberShouldMatch: (int) min
{
	minNrShouldMatch = min;
}

- (int) minimumNumberShouldMatch
{
	return minNrShouldMatch;
}

@end

@implementation LCBooleanWeight
- (id) initWithSearcher: (LCSearcher *) searcher
	minimumNumberShouldMatch: (int) min
                  query: (LCBooleanQuery *) q
{
	self = [super init];
	ASSIGN(query, q);
	ASSIGN(similarity, [query similarity: searcher]);
	minNrShouldMatch = min;
	weights = [[NSMutableArray alloc] init];
	NSArray *clauses = [query clauses];
	int i;
	for (i = 0; i < [clauses count]; i++) 
	{
		LCBooleanClause *c = [clauses objectAtIndex: i];
		[weights addObject: [[c query] createWeight: searcher]];
	}
	return self;
}

- (void) dealloc
{
	DESTROY(weights);
	DESTROY(query);
	DESTROY(similarity);
	[super dealloc];
}

- (LCQuery *) query
{
	return query;
}

- (float) value
{
	return [query boost];
}

- (float) sumOfSquaredWeights
{
	float sum = 0.0f;
	NSArray *clauses = [query clauses];
	int i;
	for (i = 0; i < [weights count]; i++) {
		LCBooleanClause *c = [clauses objectAtIndex: i];
		id <LCWeight> w = [weights objectAtIndex: i];
		if (![c isProhibited])
			sum += [w sumOfSquaredWeights]; // sum sub weights
	}
	sum *= [query boost] * [query boost]; // boost each sub-weight
	
	return sum;
}

- (void) normalize: (float) n
{
	float norm = n * [query boost]; // incorporate boost
	int i;
	NSArray *clauses = [query clauses];
	for (i = 0; i < [weights count]; i++) {
		LCBooleanClause *c = [clauses objectAtIndex: i];
		id <LCWeight> w = [weights objectAtIndex: i];
		if (![c isProhibited])
			[w normalize: norm];
	}
}

- (LCScorer *) scorer: (LCIndexReader *) reader
{
	/* LuceneKit: this is actually BooleanScorer2 in lucene */
	LCBooleanScorer *result = [[LCBooleanScorer alloc] initWithSimilarity: similarity minimumNumberShouldMatch: minNrShouldMatch];
        AUTORELEASE(result);
	NSArray *clauses = [query clauses];
	int i;
	for (i = 0; i < [weights count]; i++)
	{
		LCBooleanClause *c = [clauses objectAtIndex: i];
		id <LCWeight> w = [weights objectAtIndex: i];
		LCScorer *subScorer = [w scorer: reader];
		if (subScorer != nil)
			[result addScorer: subScorer required: [c isRequired] prohibited: [c isProhibited]];
		else if ([c isRequired])
			return nil;
	}
	return result;
}

- (LCExplanation *) explain: (LCIndexReader *) reader
				   document: (int) doc
{
        LCExplanation *sumExpl = AUTORELEASE([[LCExplanation alloc] init]);
	[sumExpl setRepresentation: @"sum of:"];
	int coord = 0;
	int maxCoord = 0;
	float sum = 0.0f;
	int i;
	NSArray *clauses = [query clauses];
	for (i = 0; i < [weights count]; i++)
	{
		LCBooleanClause *c = [clauses objectAtIndex: i];
		id <LCWeight> w = [weights objectAtIndex: i];
		LCExplanation *e = [w explain: reader document: doc];
		if (![c isProhibited]) maxCoord++;
		if ([e value] > 0) {
			if (![c isProhibited]) {
				[sumExpl addDetail: e];
				sum += [e value];
				coord++;
			} else {
				return AUTORELEASE([[LCExplanation alloc] initWithValue: 0.0f representation: @"match prohibited"]);
			}
		} else if ([c isRequired]) {
			return AUTORELEASE([[LCExplanation alloc] initWithValue: 0.0f representation: @"match required"]);
		}
	}
	[sumExpl setValue: sum];
	
	if (coord == 1) // only one clause matched
		sumExpl = [[sumExpl details] objectAtIndex: 0]; // eliminate wrapper
	
	float coordFactor = [similarity coordination: coord max: maxCoord];
	if (coordFactor == 1.0f)  // coord is no-op
		return sumExpl; // elimate wrapper
	else {
		LCExplanation *result = [[LCExplanation alloc] init];
		[result setRepresentation: @"product of:"];
		[result addDetail: sumExpl];
		LCExplanation *e = [[LCExplanation alloc] initWithValue: coordFactor representation: [NSString stringWithFormat: @"coord(%d/%d)", coord, maxCoord]];
		[result addDetail: e];
		DESTROY(e);
		[result setValue: sum * coordFactor];
		return AUTORELEASE(result);
	}
}
@end
