#import "COSetDeletion.h"

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