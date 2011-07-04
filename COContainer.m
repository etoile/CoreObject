#import "COContainer.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COContainer

+ (void) initialize
{
	if (self != [COContainer class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

- (BOOL) isOrdered
{
	return YES;
}

- (id) content
{
	return [self valueForProperty: @"contents"];
}

- (NSArray *) contentArray
{
	 // FIXME: Should return a new array, but this might break other things currently
	return [self valueForProperty: @"contents"];
}

- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	if (index == ETUndeterminedIndex)
	{
		[self addObject: object forProperty: @"contents"];
	}
	else
	{
		[self insertObject: object atIndex: index forProperty: @"contents"];
	}
}

- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	if (index == ETUndeterminedIndex)
	{
		[self removeObject: object forProperty: @"contents"];	
	}
	else
	{
		[self removeObject: object atIndex: index forProperty: @"contents"];
	}
}

@end
