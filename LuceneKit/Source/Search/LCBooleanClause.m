#include "LCBooleanClause.h"
#include "LCQuery.h"
#include "GNUstep.h"

@interface LCBooleanClause (LCPrivate)
- (void) setFields: (LCOccurType) o;
@end

@implementation LCBooleanClause
- (id) init
{
	self = [super init];
	occur = LCOccur_SHOULD;
	return self;
}

- (id) initWithQuery: (LCQuery *) q
			   occur: (LCOccurType) o
{
	self = [self init];
	ASSIGN(query, q);
	occur = o;
	return self;
}

- (void) dealloc
{
  DESTROY(query);
  [super dealloc];
}

- (LCOccurType) occur { return occur; }
- (void) setOccur: (LCOccurType) o
{
	occur = o;
}
- (NSString *) occurString
{
	switch (occur) {
		case LCOccur_MUST:
			return @"MUST";
		case LCOccur_SHOULD:
			return @"SHOULD";
		case LCOccur_MUST_NOT:
			return @"MUST_NOT";
		default:
			return nil;
	}
}

- (LCQuery *) query { return query; }
- (void) setQuery: (LCQuery *) q
{
	ASSIGN(query, q);
}

- (BOOL) isProhibited { return (LCOccur_MUST_NOT == occur); }
- (BOOL) isRequired { return (LCOccur_MUST == occur); }

- (BOOL) isEqual: (id) o
{
	if ([o isKindOfClass: [self class]] == NO)
		return NO;
	LCBooleanClause *other = (LCBooleanClause *) o;
	if ([query isEqual: [other query]] &&
                occur == [other occur])
		return YES;
	else
		return NO;
}

- (NSUInteger) hash
{
	return [query hash] ^ ((LCOccur_MUST == occur)? 1 : 0) ^ ((LCOccur_MUST_NOT == occur)? 2 : 0);
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"%@ %@", [self occurString], query];
}
@end
