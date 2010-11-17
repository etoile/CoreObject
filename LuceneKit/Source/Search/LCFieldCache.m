#include "LCFieldCache.h"
#include "LCFieldCacheImpl.h"
#include "GNUstep.h"

/**
* Expert: Maintains caches of term values.
 *
 * <p>Created: May 19, 2004 11:13:14 AM
 *
 * @author  Tim Jones (Nacimiento Software)
 * @since   lucene 1.4
 * @version $Id$
 */
@implementation LCStringIndex

- (id) initWithOrder: (NSDictionary *) values lookup: (NSArray *) l
{
	self = [super init];
	ASSIGNCOPY(order, values);
	ASSIGNCOPY(lookup, l);
	return self;
}

- (NSDictionary *) order
{
	return order;
}

- (NSArray *) lookup
{
	return lookup;
}

- (void) dealloc
{
	DESTROY(order);
	DESTROY(lookup);
	[super dealloc];
}

@end

static LCFieldCache *defaultImpl = nil;

/* To be overwritten by implementation */
@implementation LCIntParser
- (int) parseInt: (NSString *) value { return 0; }
@end

/* To be overwritten by implementation */
@implementation LCFloatParser
- (float) parseFloat: (NSString *) value { return 0.0f; }
@end

@implementation LCFieldCache
+ (LCFieldCache *) defaultCache
{
	if (defaultImpl == nil)
	{
		ASSIGN(defaultImpl, AUTORELEASE([[LCFieldCacheImpl alloc] init]));
	}
	return defaultImpl;
}

- (NSDictionary *) ints: (LCIndexReader *) reader field: (NSString *) field
{
	return nil;
}

- (NSDictionary *) ints: (LCIndexReader *) reader field: (NSString *) field
                   parser: (LCIntParser *) parser
{
	return nil;
}

- (NSDictionary *) floats: (LCIndexReader *) reader field: (NSString *) field
{
	return nil;
}

- (NSDictionary *) floats: (LCIndexReader *) reader field: (NSString *) field
                   parser: (LCFloatParser *) parser
{
	return nil;
}

- (NSDictionary *) strings: (LCIndexReader *) reader field: (NSString *) field
{
	return nil;
}

- (LCStringIndex *) stringIndex: (LCIndexReader *) reader field: (NSString *) field
{
	return nil;
}

- (id) objects: (LCIndexReader *) reader field: (NSString *) field
{
	return nil;
}

- (NSDictionary *) custom: (LCIndexReader *) reader field: (NSString *) field
		   sortComparator: (LCSortComparator *) comparator
{
	return nil;
}

@end
