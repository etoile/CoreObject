#import "CODeleteAttribute.h"

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
