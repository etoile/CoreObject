#include "LCMultiTermQuery.h"
#include "LCBooleanQuery.h"
#include "LCTermQuery.h"
#include "LCFilteredTermEnum.h"
#include "LCSmallFloat.h"
#include "GNUstep.h"

/**
 * A {@link Query} that matches documents containing a subset of terms provided
 * by a {@link FilteredTermEnum} enumeration.
 * <P>
 * <code>MultiTermQuery</code> is not designed to be used by itself.
 * <BR>
 * The reason being that it is not intialized with a {@link FilteredTermEnum}
 * enumeration. A {@link FilteredTermEnum} enumeration needs to be provided.
 * <P>
 * For example, {@link WildcardQuery} and {@link FuzzyQuery} extend
 * <code>MultiTermQuery</code> to provide {@link WildcardTermEnum} and
 * {@link FuzzyTermEnum}, respectively.
 */

@implementation LCMultiTermQuery

- (id) initWithTerm: (LCTerm *) t
{
	self = [self init];
	ASSIGN(term, t);
	return self;
}

- (void) dealloc
{
	DESTROY(term);
	[super dealloc];
}

- (LCTerm *) term { return term; }

/** Construct the enumeration to be used, expanding the pattern term. */
- (LCFilteredTermEnumerator *) enumerator: (LCIndexReader *) reader { return nil; }

- (LCQuery *) rewrite: (LCIndexReader *) reader
{
	LCBooleanQuery *query = [[LCBooleanQuery alloc] initWithCoordination: YES];
	CREATE_AUTORELEASE_POOL(pool);
	LCFilteredTermEnumerator *enumerator = [self enumerator: reader];
	do {
		LCTerm *t = [enumerator term];
		if (t != nil) 
		{
			LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: t]; // found a match
			[tq setBoost: [self boost]*[enumerator difference]]; // set the boost
			[query addQuery: tq occur: LCOccur_SHOULD]; // add to query];
                        DESTROY(tq);
		}
	} while ([enumerator hasNextTerm]);
	[enumerator close];
	DESTROY(pool);
	return AUTORELEASE(query);
}

/** Prints a user-readable version of this query. */
- (NSString *) descriptionWithField: (NSString *) field
{
	NSMutableString *buffer = [[NSMutableString alloc] init];
	if (![[term field] isEqualToString: field])
	{
		[buffer appendFormat: @"%@:", [term field]];
	}
	[buffer appendString: [term text]];
	if ([self boost] != 1.0f)
	{
		[buffer appendFormat: @"^%f", [self boost]];
	}
	return AUTORELEASE(buffer);
}

- (BOOL) isEqual: (id) o
{
	if (self == o) return YES;
	if (![o isKindOfClass: [LCMultiTermQuery class]]) return NO;
	LCMultiTermQuery *multiTermQuery = (LCMultiTermQuery *) o;
	if (![term isEqual: [multiTermQuery term]]) return NO;
	return YES;
}

- (NSUInteger) hash
{
	return [term hash] + FloatToIntBits([self boost]);
}

@end
