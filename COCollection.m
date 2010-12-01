#import "COCollection.h"

@implementation COCollection

- (BOOL) isOrdered
{
	return NO;
}

- (NSArray *) contentArray
{
	return [[self content] allObjects];
}

@end