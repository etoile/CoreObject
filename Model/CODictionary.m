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

@interface COObject ()
- (id) copyWithZone: (NSZone *)aZone;
@end

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

- (void)resetInternalState
{
	_content = [NSMutableDictionary new];
}

- (id)initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	[self resetInternalState];
	return self;
}

// TODO: Migrate EtoileUI to COCopier and remove.
- (id) copyWithZone: (NSZone *)aZone
{
	CODictionary *newObject = [super copyWithZone: aZone];
	newObject->_content = [_content mutableCopyWithZone: aZone];
	ETAssert([[newObject allKeys] isEqualToArray: [self allKeys]]);
	return newObject;
}

/**
 * Prevents -[COObject awakeFromDeserialization] to check that -tags is a valid 
 * collection.
 *
 * For a loaded CODictionary, -tags return nil because tags are not serialized.
 */
- (void)awakeFromDeserialization
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

- (COItem *)storeItem
{
	ETAssert(_content != nil);

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

	return [self storeItemWithTypes: types values: values];
}

- (void)setStoreItem: (COItem *)aStoreItem
{
	[self resetInternalState];
	[self validateStoreItem: aStoreItem];

	ETModelDescriptionRepository *repo = [[[self persistentRoot] parentContext] modelRepository];
	ETEntityDescription *rootType = [repo descriptionForName: @"Object"];

	for (NSString *property in [aStoreItem attributeNames])
	{
		ETPropertyDescription *propertyDesc =
			[ETPropertyDescription descriptionWithName: property type: rootType];

        if ([property isEqualToString: kCOObjectEntityNameProperty])
        {
            // HACK
            continue;
        }

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

	[self awakeFromDeserialization];
}

@end
