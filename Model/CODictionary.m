/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "CODictionary.h"
#import "COObjectGraphContext+Private.h"
#import "COSerialization.h"

@interface COObject ()
- (id)serializedValueForPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
 univaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
@end

@implementation COObject (CODictionarySerialization)

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

- (COItem *)storeItemFromDictionaryForPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
	NILARG_EXCEPTION_TEST(aPropertyDesc);

	NSDictionary *dict = [self serializedValueForPropertyDescription: aPropertyDesc];
	NSMutableDictionary *types =
		[NSMutableDictionary dictionaryWithCapacity: [dict count]];
	NSMutableDictionary *values =
		[NSMutableDictionary dictionaryWithCapacity: [dict count]];

	for (NSString *key in [dict allKeys])
	{
		NSAssert2([self isSerializablePrimitiveValue: key],
			@"Unsupported key type %@ in %@. For dictionary serialization, "
			  "keys must be a primitive CoreObject values (NSString, NSNumber or NSData).",
			  key, dict);
	
		id value = [dict objectForKey: key];
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

	return [self storeItemWithUUID: [_additionalStoreItemUUIDs objectForKey: [aPropertyDesc name]]
	                         types: types
	                        values: values
	                    entityName: @"CODictionary"];
}

- (NSDictionary *)dictionaryFromStoreItem: (COItem *)aStoreItem
                   forPropertyDescription: (ETPropertyDescription *)propertyDesc
{
	NILARG_EXCEPTION_TEST(aStoreItem);
	NILARG_EXCEPTION_TEST(propertyDesc);

	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	for (NSString *property in [aStoreItem attributeNames])
	{
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
		            univaluedPropertyDescription: propertyDesc];
		[dict setObject: value forKey: property];
	}

	// FIXME: Make read-only if needed
	return dict;
}

@end

@implementation COItem (CODictionarySerialization)

- (BOOL)isAdditionalItem
{
	return [[self valueForAttribute: kCOObjectEntityNameProperty] isEqualToString: @"CODictionary"];
}

@end
