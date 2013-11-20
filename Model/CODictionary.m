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
- (BOOL) isCoreObjectEntityType: (ETEntityDescription *)aType;
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

- (COType)serializedTypeForValue: (id)value
{
	if ([value isKindOfClass: [COObject class]])
	{
		return kCOTypeReference;
	}
	else if ([value isKindOfClass: [NSString class]])
	{
		return kCOTypeString;
	}
	else if ([value isKindOfClass: [NSNumber class]])
	{
		// TODO: A bit ugly, would be better to add new entity descriptions
		// such as NSBOOLNumber, NSCGFloatNumber etc.
		if (strcmp([value objCType], @encode(BOOL)) == 0
		 || strcmp([value objCType], @encode(NSInteger)) == 0
		 || strcmp([value objCType], @encode(NSUInteger)) == 0)
		{
			return kCOTypeInt64;
		}
		else if (strcmp([value objCType], @encode(CGFloat)) == 0
		      || strcmp([value objCType], @encode(double)) == 0)
		{
			return kCOTypeDouble;
		}
	}
	else if ([value isKindOfClass: [NSDate class]])
	{
		return kCOTypeBlob;
	}
	else
	{
		NSAssert1(NO, @"Unsupported serialization type for %@", value);
	}
	return 0;
}

- (COItem *)storeItem
{
	ETAssert(_content != nil);

	NSMutableDictionary *types =
		[NSMutableDictionary dictionaryWithCapacity: [_content count]];
	NSMutableDictionary *values =
		[NSMutableDictionary dictionaryWithCapacity: [_content count]];

	for (NSString *key in [_content allKeys])
	{
		id value = [_content objectForKey: key];
		id serializedValue = [self serializedValueForValue: value];
		// FIXME: Use [self serializedTypeForPropertyDescription: propertyDesc value: serializedValue];
		// Look up the property description in the owner object entity
		// description. For example, 'Group.personsByName' and 
		// [[groupEntityDesc propertyDescriptionForName: @"personsByName"] type]
		// just to get our element type.
		NSNumber *serializedType =
			[NSNumber numberWithInteger: [self serializedTypeForValue: value]];
	
		[values setObject: serializedValue forKey: key];
		[types setObject: serializedType forKey: key];
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
