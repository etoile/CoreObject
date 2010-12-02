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
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	[self addObject: object forProperty: @"contents"];
}
- (void) insertObject: (id)object atIndex: (NSUInteger)index
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	[self insertObject: object atIndex: index forProperty: @"contents"];
}
- (void) removeObject: (id)object
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	[self removeObject: object forProperty: @"contents"];
}
- (void) removeObject: (id)object atIndex: (NSUInteger)index
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	[self removeObject: object atIndex: index forProperty: @"contents"];
}

@end
