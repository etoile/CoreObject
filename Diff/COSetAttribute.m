#import "COSetAttribute.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSetAttribute

@synthesize type;
@synthesize value;


- (BOOL) isEqualIgnoringSourceIdentifier: (id)other
{
	return [super isEqualIgnoringSourceIdentifier: other]
	&&	type == ((COSetAttribute*)other).type
	&&	[value isEqual: ((COSetAttribute*)other).value];
}

- (NSUInteger) hash
{
	return 4265092495078449026ULL ^ [super hash] ^ type ^ [value hash];
}

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			   type: (COType)aType
			  value: (id)aValue
{
	NILARG_EXCEPTION_TEST(aValue);
	self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
	type = aType;
	value = [aValue copy];
	return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"set %@.%@ = %@ (%@)", UUID, attribute, value, sourceIdentifier];
}

- (NSSet *) insertedEmbeddedItemUUIDs
{
	if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
	{
		if (COTypeIsPrimitive(type))
		{
			return [NSSet setWithObject: value];
		}
		else
		{
			if (COTypeIsOrdered(type))
			{
				return [NSSet setWithArray: value];
			}
			else
			{
				return [NSSet setWithSet: value];
			}
		}
	}
	else
	{
		return [NSSet set];
	}
}

@end