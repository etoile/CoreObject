#import "COSequenceModification.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSequenceModification

@synthesize type;
@synthesize objects;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			  range: (NSRange)aRange
			   type: (COType)aType
			objects: (NSArray *)anArray
{
	NILARG_EXCEPTION_TEST(anArray);
	self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier range: aRange];
	type = aType;
	objects = [[NSArray alloc] initWithArray: anArray copyItems: YES];
	return self;
}

- (void)dealloc
{
	[objects release];
	[super dealloc];
}

- (BOOL) isEqualIgnoringSourceIdentifier: (id)other
{
	return [super isEqualIgnoringSourceIdentifier: other]
	&& type == ((COSequenceModification*)other).type
	&& [objects isEqual: ((COSequenceModification*)other).objects];
}

- (NSUInteger) hash
{
	return 11773746616539821587ULL ^ [super hash] ^ type ^ [objects hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"replace %@.%@[%d:%d] with %@ (%@)", UUID, attribute, (int)range.location, (int)range.length, objects, sourceIdentifier];
}

- (NSSet *) insertedEmbeddedItemUUIDs
{
	if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
	{
		return [NSSet setWithArray: objects];
	}
	else
	{
		return [NSSet set];
	}
}

@end
