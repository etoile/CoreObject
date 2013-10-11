/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import "COCollection.h"
#import "COEditingContext.h"
#import "COPersistentRoot.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation COCollection

+ (void) initialize
{
	if (self != [COCollection class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

+ (ETPropertyDescription *)contentPropertyDescriptionWithName: (NSString *)aName
                                                         type: (NSString *)aType
                                                     opposite: (NSString *)oppositeType
{
	ETPropertyDescription *contentProperty = 
		[ETPropertyDescription descriptionWithName: aName type: (id)aType];
	[contentProperty setMultivalued: YES];
	[contentProperty setOpposite: (id)oppositeType];
	[contentProperty setOrdered: YES];
	[contentProperty setPersistent: YES];
	return contentProperty;
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

- (ETUTI *)objectType
{
	ETPropertyDescription *propertyDesc =
		[[self entityDescription] propertyDescriptionForName: [self contentKey]];
	ETModelDescriptionRepository *repo = [[[self persistentRoot] parentContext] modelRepository];

	return [ETUTI typeWithClass: [repo classForEntityDescription: [propertyDesc type]]];
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
	return @"objects";
}

- (BOOL) isOrdered
{
	// TODO: If too slow, return the boolean directly.
	return [[[self entityDescription] propertyDescriptionForName: [self contentKey]] isOrdered];
}

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
	[self insertObject: object atIndex: index hint: hint forProperty: [self contentKey]];
	[self didUpdate];
}

- (void) removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	[self removeObject: object atIndex: index hint: hint forProperty: [self contentKey]];
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

