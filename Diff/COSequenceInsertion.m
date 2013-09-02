#import "COSequenceInsertion.h"

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