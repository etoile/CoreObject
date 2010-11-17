#include "LCPrefixQuery.h"
#include "LCBooleanQuery.h"
#include "LCTermQuery.h"
#include "LCTermEnum.h"
#include "LCSmallFloat.h"
#include "NSString+Additions.h"
#include "GNUstep.h"

@implementation LCPrefixQuery

- (id) initWithTerm: (LCTerm *) p
{
	self = [self init];
	ASSIGN(prefix, p);
	return self;
}

- (LCQuery *) rewrite: (LCIndexReader *) reader
{
	LCBooleanQuery *query = [[LCBooleanQuery alloc] initWithCoordination: YES];
	CREATE_AUTORELEASE_POOL(pool);
	LCTermEnumerator *enumerator = [reader termEnumeratorWithTerm: prefix];
	NSString *prefixText = [prefix text];
	NSString *prefixField = [prefix field];
	do {
		LCTerm *term = [enumerator term];
		if (term != nil &&
			[[term text] hasPrefix: prefixText] &&
			[[term field] isEqualToString: prefixField])
		{
			LCTermQuery *tq = [[LCTermQuery alloc] initWithTerm: term]; // found a match
			[tq setBoost: [self boost]]; // set the boost
			[query addQuery: tq occur: LCOccur_SHOULD]; // add to quer
			DESTROY(tq);
		} else {
			break;
		}
	} while ([enumerator hasNextTerm]);
	[enumerator close];
	DESTROY(pool);
	return AUTORELEASE(query);
}

- (void) dealloc
{
	DESTROY(prefix);
	[super dealloc];
}

- (LCTerm *) prefix
{
	return prefix;
}

- (NSString *) descriptionWithField: (NSString *) field
{
	NSMutableString *buffer = [[NSMutableString alloc] init];
	if (![[prefix field] isEqualToString: field])
	{
		[buffer appendFormat: @"%@:", [prefix field]];
    }
	[buffer appendFormat: @"%@*", [prefix text]];
	[buffer appendString: LCStringFromBoost([self boost])];
	return AUTORELEASE(buffer);
}

- (BOOL) isEqual: (id) o
{
	if ([o isKindOfClass: [self class]] == NO)
	{
		return NO;
	}
	LCPrefixQuery *other = (LCPrefixQuery *) o;
	return (([self boost] == [other boost]) && ([[self prefix] isEqual: [other prefix]]));
}

- (NSUInteger) hash
{
	return FloatToIntBits([self boost]) ^ [prefix hash] ^ 0x6634D93C;
}

@end
