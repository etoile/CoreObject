#import "COContainer.h"

@implementation COContainer

- (BOOL) isOrdered
{
	return YES;
}
- (BOOL) isEmpty
{
	return [[self valueForProperty: @"contents"] count] == 0;
}
- (id) content
{
	return [self valueForProperty: @"contents"];
}
- (NSArray *) contentArray
{
	return [self valueForProperty: @"contents"];
}

- (void) addObject: (id)object
{
	[self addObject: object forProperty: @"contents"];
}
- (void) insertObject: (id)object atIndex: (NSUInteger)index
{
	[self insertObject: object atIndex: index forProperty: @"contents"];
}
- (void) removeObject: (id)object
{
	[self removeObject: object forProperty: @"contents"];
}
- (void) removeObject: (id)object atIndex: (NSUInteger)index
{
	[self removeObject: object atIndex: index forProperty: @"contents"];
}

@end
