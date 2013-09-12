#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/Macros.h>
#import "COItemGraphEdit.h"
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
	return self;
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
