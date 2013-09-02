#import "COSequenceDeletion.h"

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