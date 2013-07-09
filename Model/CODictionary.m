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

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *collection = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add the 
	// property descriptions that we will inherit through the parent
	if ([[collection name] isEqual: [CODictionary className]] == NO)
		return collection;

	return collection;	
}

- (id)init
{
	SUPERINIT;
	_content = [NSMutableDictionary new];
	return self;
}

- (void)willLoad
{
	[super willLoad];
	_content = [NSMutableDictionary new];
}

- (void)dealloc
{
	DESTROY(_content);
	[super dealloc];
}

/* Prevent -[COObject awakeFromFetch] to check that -tags is a valid collection.
For a loaded object, -tags return nil because tags are not serialized. */
- (void)awakeFromFetch
{
	ETAssert(_content != nil);
}

#pragma mark Keyed Collection Protocol
#pragma mark -


- (NSArray *)allKeys
{
	return [_content allKeys];
}

- (NSArray *)allValues
{
	return [_content allValues];
}

- (id)objectForKey: (id)aKey
{
	return [_content objectForKey: aKey];
}

- (void)setObject: (id)anObject forKey: (id)aKey
{
	[_content setObject: anObject forKey: aKey];
}

- (void)removeObjectForKey: (id)aKey
{
	[_content removeObjectForKey: aKey];
}

- (void)removeAllObjects
{
	[_content removeAllObjects];
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
	return _content;
}

- (NSArray *)contentArray
{
	return [_content allValues];
}

- (NSArray *)arrayRepresentation
{
	return [_content arrayRepresentation];
}

#pragma mark Collection Mutation Protocol
#pragma mark -

- (void)insertObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	[_content setObject: object forKey: [[hint ifResponds] key]];
}

- (void)removeObject: (id)object atIndex: (NSUInteger)index hint: (id)hint
{
	[_content removeObjectForKey: [[hint ifResponds] key]];
}

#pragma mark Serialization
#pragma mark -

/* For -[COPersistentRoot saveCommitWithMetadata:] and old serialization */
- (NSArray *)persistentPropertyNames
{
	return [self allKeys];
}

/* For old serialization */
- (id)serializedValueForProperty: (NSString *)key
{
	return [self objectForKey: key];
}

/* For old serialization */
- (void)setSerializedValue: (id)value forProperty: (NSString *)key
{
	if ([key isEqualToString: @"_entity"])
		return;

	[self setObject: value forKey: key];
}

- (COItem *)storeItem
{
	ETModelDescriptionRepository *repo = [[[self persistentRoot] parentContext] modelRepository];
	ETEntityDescription *rootType = [repo descriptionForName: @"Object"];
	NSMutableDictionary *types =
		[NSMutableDictionary dictionaryWithCapacity: [_content count]];
	NSMutableDictionary *values =
		[NSMutableDictionary dictionaryWithCapacity: [_content count]];

	for (NSString *key in [_content allKeys])
	{
		ETPropertyDescription *propertyDesc =
			[ETPropertyDescription descriptionWithName: key type: rootType];
		id serializedValue = [self serializedValueForValue: [_content objectForKey: key]];
		NSNumber *serializedType =
			[self serializedTypeForPropertyDescription: propertyDesc value: serializedValue];
	
		[values setObject: serializedValue forKey: [propertyDesc name]];
		[types setObject: serializedType forKey: [propertyDesc name]];
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
		[_content setObject: value forKey: property];
	}
}

@end
