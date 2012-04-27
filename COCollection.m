/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COCollection.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COCollection

+ (void) initialize
{
	if (self != [COCollection class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [COCollection className]] == NO) 
		return collection;

	return collection;	
}

- (void)addObjects: (NSArray *)anArray
{
	for (id object in anArray)
	{
		[self addObject: object];
	}
}

- (void)didReload
{
	[self didUpdate];
}

- (void)didUpdate
{
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: ETCollectionDidUpdateNotification object: self];
}

- (NSString *) contentKey
{
	return @"contents";
}

- (void)addObject: (id)object forProperty: (NSString *)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (![desc isMultivalued])
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call addObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
	}
	
	// FIXME: Modify the value directly.. this will require refactoring setValue:forProperty:
	// so that we can run the relationship integrity code and other checks directly
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]] || [copy isKindOfClass: [NSMutableSet class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	
	[copy addObject: object];
	[self setValue: copy forProperty: key];
	[copy release];
}

- (void)insertObject: (id)object atIndex: (NSUInteger)index forProperty: (NSString *)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (!([desc isMultivalued] && [desc isOrdered]))
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call inesrtObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
	}
	
	// FIXME: see comment in addObject:ForProperty
	
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	
	[copy insertObject: object atIndex: index];
	[self setValue: copy forProperty: key];
	[copy release];
}

- (void)removeObject: (id)object forProperty: (NSString *)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (![desc isMultivalued])
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call removeObject:forProperty: for %@ which is not a multivalued property of %@", key, self];
	}
	
	// FIXME: see comment in addObject:ForProperty
	
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]] || [copy isKindOfClass: [NSMutableSet class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	[copy removeObject: object];
	[self setValue: copy forProperty: key];
	[copy release];
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index forProperty: (NSString *)key
{
	ETPropertyDescription *desc = [[self entityDescription] propertyDescriptionForName: key];
	if (!([desc isMultivalued] && [desc isOrdered]))
	{
		[NSException raise: NSInvalidArgumentException format: @"attempt to call removeObject:atIndex:forProperty: for %@ which is not an ordered multivalued property of %@", key, self];
	}
	
	// FIXME: see comment in addObject:ForProperty
	
	id copy = [[self valueForProperty: key] mutableCopy];
	if (!([copy isKindOfClass: [NSMutableArray class]]))
	{
		[NSException raise: NSInternalInconsistencyException format: @"Multivalued property not set up properly"];
	}
	
	[copy removeObject: object atIndex: index hint: nil];
	[self setValue: copy forProperty: key];
	[copy release];
}

#if 0
- (BOOL) isOrdered
{
	// TODO: If too slow, return the boolean directly.
	return [[[self entityDescription] propertyDescriptionForName: [self contentKey] isOrdered];
}
#endif

- (id) content
{
	return [self valueForProperty: [self contentKey]];
}

- (NSArray *) contentArray
{
	 // FIXME: Should return a new array, but this might break other things currently
	return [self valueForProperty: [self contentKey]];
}

- (void) insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	if (index == ETUndeterminedIndex)
	{
		[self addObject: object forProperty: [self contentKey]];
	}
	else
	{
		[self insertObject: object atIndex: index forProperty: [self contentKey]];
	}
	[self didUpdate];
}

- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	assert([object editingContext] == [self editingContext]); // FIXME: change to an exception
	if (index == ETUndeterminedIndex)
	{
		[self removeObject: object forProperty: [self contentKey]];	
	}
	else
	{
		[self removeObject: object atIndex: index forProperty: [self contentKey]];
	}
	[self didUpdate];
}

- (id)objectForIdentifier: (NSString *)anId
{
	for (id object in [self content])
	{
		if ([[object identifier] isEqualToString: anId])
		{
			return object;
		}
	}
	return nil;
}

- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery
{
	NSMutableArray *result = [NSMutableArray array];

	for (COObject *object in [self content])
	{
		if ([[aQuery predicate] evaluateWithObject: object])
		{
			[result addObject: object];
		}
	}

	return result;
}

@end


@implementation COObject (COCollectionTypeQuerying)

- (BOOL)isGroup
{
	return NO;
}

- (BOOL)isTag
{
	return NO;
}

- (BOOL)isContainer
{
	return NO;
}

- (BOOL)isLibrary
{
	return NO;
}

@end

