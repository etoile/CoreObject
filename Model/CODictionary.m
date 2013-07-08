/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "CODictionary.h"
#import "COItem.h"
#import "COPersistentRoot.h"
#import "COSerialization.h"

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
	[_variableStorage setObject: object forKey: [[hint ifResponds] key]];
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	[_variableStorage removeObjectForKey: [[hint ifResponds] key]];
}

#pragma mark Serialization
#pragma mark -

- (COItem *) storeItem
{
	ETModelDescriptionRepository *repo = [[[self persistentRoot] parentContext] modelRepository];
	ETEntityDescription *rootType = [repo descriptionForName: @"Object"];
	NSMutableDictionary *types =
		[NSMutableDictionary dictionaryWithCapacity: [_variableStorage count]];
	NSMutableDictionary *values =
		[NSMutableDictionary dictionaryWithCapacity: [_variableStorage count]];

	for (NSString *key in [_variableStorage allKeys])
	{
		ETPropertyDescription *propertyDesc =
			[ETPropertyDescription descriptionWithName: key type: rootType];

		id value = [self serializedValueForPropertyDescription: propertyDesc];
		[values setObject: value
		           forKey: [propertyDesc name]];
		[types setObject: [self serializedTypeForPropertyDescription: propertyDesc value: value]
		          forKey: [propertyDesc name]];
	}
	
	return [COItem itemWithTypesForAttributes: types valuesForAttributes: values];
}

- (void)setStoreItem: (COItem *)aStoreItem
{
	ETModelDescriptionRepository *repo = [[[self persistentRoot] parentContext] modelRepository];
	ETEntityDescription *rootType = [repo descriptionForName: @"Object"];

	for (NSString *property in [aStoreItem attributeNames])
	{
		ETPropertyDescription *propertyDesc =
			[ETPropertyDescription descriptionWithName: property type: rootType];

		id serializedValue = [aStoreItem valueForAttribute: property];
		COType serializedType = [aStoreItem typeForAttribute: property];
	
		if (propertyDesc == nil)
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Tried to set serialized value %@ of type %@ "
			                     "for property %@ missing in the metamodel %@",
			                    serializedValue, @(serializedType), [propertyDesc name], [self entityDescription]];
		}

		id value = [self valueForSerializedValue: serializedValue
		                                  ofType: serializedType
		                     propertyDescription: propertyDesc];
		[self setSerializedValue: value forProperty: property];
	}
}

@end
