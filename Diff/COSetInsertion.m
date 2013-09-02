#import "COSetInsertion.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSetInsertion

@synthesize type;
@synthesize object;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			   type: (COType)aType
			 object: (id)anObject
{
	NILARG_EXCEPTION_TEST(anObject);
	self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
	type = aType;
	object = [anObject copy];
	return self;
}

- (void)dealloc
{
	[object release];
	[super dealloc];
}

- (BOOL) isEqualIgnoringSourceIdentifier: (id)other
{
	return [super isEqualIgnoringSourceIdentifier: other]
	&& type == ((COSetInsertion*)other).type
	&& [object isEqual: ((COSetInsertion*)other).object];
}

- (NSUInteger) hash
{
	return 595258568559201742ULL ^ [super hash] ^ type ^ [object hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"insert into set %@.%@ value %@ (%@)", UUID, attribute, object, sourceIdentifier];
}

- (NSSet *) insertedEmbeddedItemUUIDs
{
	if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
	{
		return [NSSet setWithObject: object];
	}
	else
	{
		return [NSSet set];
	}
}

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit
{
	return [anEdit isKindOfClass: [COSetInsertion class]]; // COSetDeletion is a subclass
}

@end