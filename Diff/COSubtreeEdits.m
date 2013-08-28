#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/Macros.h>
#import "COSubtreeEdits.h"
#import "COType.h"
#import "COSequenceMerge.h"

#pragma mark base class

@implementation COItemGraphEdit

@synthesize UUID;
@synthesize attribute;
@synthesize sourceIdentifier;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(anAttribute);
	NILARG_EXCEPTION_TEST(aSourceIdentifier);	
	SUPERINIT;
	UUID = [aUUID copy];
	attribute = [anAttribute copy];
	sourceIdentifier = [aSourceIdentifier copy];
	return self;
}

- (id) copyWithZone: (NSZone *)aZone
{
	return [self retain];
}

- (void) dealloc
{
	[UUID release];
	[attribute release];
	[sourceIdentifier release];
	[super dealloc];
}

- (BOOL) isEqualIgnoringSourceIdentifier: (id)other
{
	return [other isKindOfClass: [self class]]
		&&	[UUID isEqual: ((COItemGraphEdit*)other).UUID]
		&&	[attribute isEqual: ((COItemGraphEdit*)other).attribute];
}

- (NSUInteger) hash
{
	return 17540461545992478206ULL ^ [UUID hash] ^ [attribute hash] ^ [sourceIdentifier hash];
}

- (BOOL) isEqual: (id)other
{
	return [self isEqualIgnoringSourceIdentifier: other]
		&& [sourceIdentifier isEqual: ((COItemGraphEdit*)other).sourceIdentifier];
}

- (NSSet *) insertedEmbeddedItemUUIDs
{
	return [NSSet set];
}

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit
{
	return [anEdit isMemberOfClass: [self class]];
}

@end


#pragma mark set, delete attribute

@implementation COSetAttribute

@synthesize type;
@synthesize value;

- (void)dealloc
{
	[value release];
	[super dealloc];
}

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


@implementation CODeleteAttribute

- (NSUInteger) hash
{
	return 10002940502939600064ULL ^ [super hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"delete %@.%@ (%@)", UUID, attribute, sourceIdentifier];
}

@end


#pragma mark editing set multivalueds

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


@implementation COSetDeletion

- (NSUInteger) hash
{
	return 1310827214389984141ULL ^ [super hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"delete from set %@.%@ value %@ (%@)", UUID, attribute, object, sourceIdentifier];
}

- (NSSet *) insertedEmbeddedItemUUIDs
{
	return [NSSet set];
}

@end


#pragma mark editing array multivalueds


@implementation COSequenceEdit

@synthesize range;

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
			  range: (NSRange)aRange
{
	self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier];
	range = aRange;
	return self;
}

- (NSComparisonResult) compare: (COSequenceEdit*)other
{
	if ([other range].location > [self range].location)
	{
		return NSOrderedAscending;
	}
	if ([other range].location == [self range].location)
	{
		return NSOrderedSame;
	}
	else
	{
		return NSOrderedDescending;
	}
}

- (BOOL) overlaps: (COSequenceEdit *)other
{
	return COOverlappingRanges(range, other.range);
}

- (BOOL) isEqualIgnoringSourceIdentifier:(id)other
{
	return [super isEqualIgnoringSourceIdentifier: other]
		&& NSEqualRanges(range, ((COSequenceEdit*)other).range);
}

- (NSUInteger) hash
{
	return 9723954873297612448ULL ^ [super hash] ^ range.location ^ range.length;
}

- (BOOL) isSameKindOfEdit: (COItemGraphEdit*)anEdit
{
	return [anEdit isKindOfClass: [COSequenceEdit class]];
}

@end

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
	&& type == ((COSequenceInsertion*)other).type
	&& [objects isEqual: ((COSequenceInsertion*)other).objects];
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



@implementation COSequenceInsertion

- (id) initWithUUID: (ETUUID *)aUUID
		  attribute: (NSString *)anAttribute
   sourceIdentifier: (id)aSourceIdentifier
		   location: (NSUInteger)aLocation
			   type: (COType)aType
			objects: (NSArray *)anArray
{
	self = [super initWithUUID: aUUID attribute: anAttribute sourceIdentifier: aSourceIdentifier range: NSMakeRange(aLocation, 0) type: aType objects: anArray];
	return self;
}
			  
- (NSUInteger) hash
{
	return 14584168390782580871ULL ^ [super hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"insert at %@.%@[%d] value %@ (%@)", UUID, attribute, (int)range.location, objects, sourceIdentifier];
}

@end




@implementation COSequenceDeletion

- (NSUInteger) hash
{
	return 17441750424377234775ULL ^ [super hash];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"delete range %@.%@[%d:%d] (%@)", UUID, attribute, (int)range.location, (int)range.length, sourceIdentifier];
}

@end
