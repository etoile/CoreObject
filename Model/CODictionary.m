/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "CODictionary.h"

#pragma GCC diagnostic ignored "-Wprotocol"

@implementation CODictionary

+ (void)initialize
{
	if (self != [CODictionary class])
		return;

	[self applyTraitFromClass: [ETCollectionTrait class]];
	[self applyTraitFromClass: [ETMutableCollectionTrait class]];
}

+ (ETEntityDescription *) ewEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [CODictionary className]] == NO)
		return collection;

	return collection;	
}

#pragma mark Keyed Collection Protocol
#pragma mark -

- (NSArray *)allKeys
{
	return [_variableStorage allKeys];
}

- (NSArray *)allValues
{
	return [_variableStorage allValues];
}

- (id)objectForKey: (id)aKey
{
	return [_variableStorage objectForKey: aKey];
}

- (void)setObject: (id)anObject forKey: (id)aKey
{
	[_variableStorage setObject: anObject forKey: aKey];
}

- (void)removeObjectForKey: (id)aKey
{
	[_variableStorage removeObjectForKey: aKey];
}

- (void)removeAllObjects
{
	[_variableStorage removeAllObjects];
}

#pragma mark Collection Protocol
#pragma mark -

+ (Class)mutableClass
{
	return self;
}

- (BOOL)isOrdered
{
	return NO;
}

- (BOOL)isKeyed
{
	return YES;
}

- (id) content
{
	return _variableStorage;
}

- (NSArray *)contentArray
{
	return [_variableStorage allValues];
}

- (NSArray *)arrayRepresentation
{
	return [_variableStorage arrayRepresentation];
}

#pragma mark Collection Mutation Protocol
#pragma mark -

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	// FIXME: NSMapTable doesn't implement the collection protocols
	//[_variableStorage insertObject: object atIndex: index hint: hint];
	[_variableStorage setObject: object forKey: [[hint ifResponds] key]];
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	// FIXME: NSMapTable doesn't implement the collection protocol
	//[_variableStorage removeObject: object atIndex: index hint: hint];
	[_variableStorage removeObjectForKey: [[hint ifResponds] key]];
}

@end
