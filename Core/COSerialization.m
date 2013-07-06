/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COSerialization.h"
#import "COObject.h"
#import "COItem.h"
#import "COPath.h"

#include <objc/runtime.h>

@implementation COObject (COSerialization)

/* Returns whether the given value is a primitive type supported by CoreObject
serialization. */
- (BOOL) isSerializablePrimitiveValue: (id)value
{
	return ([value isKindOfClass: [NSString class]]
		|| [value isKindOfClass: [NSNumber class]]
		|| [value isKindOfClass: [NSData class]]);
}

/* See ETGeometry.h in EtoileUI
 
There is no support for null scalar structs in AppKit unlike CoreGraphics. 
EtoileUI extends AppKit to support them. Could be better to move them to 
EtoileFoundation. */
static const NSPoint CONullPoint = {FLT_MIN, FLT_MIN};
static const NSSize CONullSize = {FLT_MIN, FLT_MIN};
static const NSRect CONullRect = {{FLT_MIN, FLT_MIN}, {FLT_MIN, FLT_MIN}};

/* Returns whether the given value is a scalar type supported by CoreObject 
serialization. */
- (BOOL) isSerializableScalarValue: (id)value
{
	const char *type = [value objCType];
	
	return ((strcmp(type, @encode(NSPoint)) == 0)
		|| (strcmp(type, @encode(NSSize)) == 0)
		|| (strcmp(type, @encode(NSRect)) == 0)
		|| (strcmp(type, @encode(NSRange)) == 0));
}

/* Returns the CoreObject serialization result for a NSValue.
 
Nil is returned when the value type is unsupported by CoreObject serialization. */
- (id)serializedValueForScalarValue: (NSValue *)value
{
	NSParameterAssert([value isKindOfClass: [NSValue class]]);
	const char *type = [value objCType];

	if (strcmp(type, @encode(NSPoint)) == 0)
	{
		NSPoint point = [value pointValue];
		if (NSEqualPoints(point, CONullPoint))
		{
			return @"null-point";
		}
		return NSStringFromPoint(point);
	}
	else if (strcmp(type, @encode(NSSize)) == 0)
	{
		NSSize size = [value sizeValue];
		if (NSEqualSizes(size, CONullSize))
		{
			return @"null-size";
		}
		return NSStringFromSize(size);
	}
	else if (strcmp(type, @encode(NSRect)) == 0)
	{
		NSRect rect = [value rectValue];
		if (NSEqualRects(rect, CONullRect))
		{
			return @"null-rect";
		}
		return NSStringFromRect(rect);
	}
	else if (strcmp(type, @encode(NSRange)) == 0)
	{
		return NSStringFromRange([value rangeValue]);
	}
	return nil;
}

- (id)serializedValueForValue: (id)value
{
	if (value == nil)
	{
		return [NSNull null];
	}
	else if ([value isKindOfClass: [COObject class]])
	{
		if ([value persistentRoot] == [self persistentRoot])
		{
			return [value UUID];
		}
		else
		{
			NSAssert([value isRoot], @"A property must point to a root object "
				"for references accross persistent roots");
			return [COPath pathWithPersistentRoot: [[value persistentRoot] UUID]
			                               branch: [[[value persistentRoot] commitTrack] UUID]];
		}
	}
	else if ([value isKindOfClass: [NSArray class]])
	{
		NSMutableArray *array = [NSMutableArray arrayWithCapacity: [value count]];

		for (id element in value)
		{
			[array addObject: [self serializedValueForValue: element]];
		}
		return array;
	}
	else if ([value isKindOfClass: [NSSet class]])
	{
		NSMutableSet *set = [NSMutableSet setWithCapacity: [value count]];
		
		for (id element in value)
		{
			[set addObject: [self serializedValueForValue: element]];
		}
		return set;
	}
	else if ([value isKindOfClass: [NSDictionary class]])
	{
		NSAssert(NO, @"Serializing a dictionary is not supported, the dictionary "
			"must be converted to a COObject and its content stored in the "
			"COObject variable storage.");
	}
	else if ([self isSerializablePrimitiveValue: value])
	{
		return value;
	}
	else if ([self isSerializableScalarValue: value])
	{
		return [self serializedValueForScalarValue: value];
	}
	else
	{
		// FIXME: Don't encode using the keyed archiving unless the property
		// description requires it explicitly.
		return [NSKeyedArchiver archivedDataWithRootObject: value];
	}
	return nil;
}

- (BOOL) isCoreObjectEntityType: (ETEntityDescription *)aType
{
	ETEntityDescription *type = aType;
	// TODO: Determine more directly
	do
	{
		if ([[type name] isEqualToString: @"COObject"])
			return YES;

		type = [type parent];
	}
	while (type != nil);

	return NO;
}

/* Returns whether the given value is a scalar type name supported by CoreObject 
serialization. */
- (BOOL) isSerializableScalarTypeName: (NSString *)aTypeName
{
	return ([aTypeName isEqualToString: @"NSRect"]
	     || [aTypeName isEqualToString: @"NSSize"]
	     || [aTypeName isEqualToString: @"NSPoint"]
	     || [aTypeName isEqualToString: @"NSRange"]);
}

- (COType)serializedTypeForUnivaluedPropertyDescription: (ETPropertyDescription *)aPropertyDesc
                                                ofValue: (id)value
{
	ETEntityDescription *type = [aPropertyDesc type];
	NSString *typeName = [type name];

	if ([self isCoreObjectEntityType: type])
	{
		if (value == nil || ([value persistentRoot] == [self persistentRoot]))
		{
			return ([aPropertyDesc isComposite] ? kCOCompositeReferenceType : kCOReferenceType);
		}
		else
		{
			NSAssert([value isRoot], @"A property must point to a root object "
				"for references accross persistent roots");
			return kCOReferenceType;
		}
	}
	else if ([typeName isEqualToString: @"BOOL"]
	      || [typeName isEqualToString: @"NSInteger"]
	      || [typeName isEqualToString: @"NSUInteger"])
	{
		return kCOInt64Type;
	}
	else if ([typeName isEqualToString: @"CGFloat"]
		 || [typeName isEqualToString: @"Double"])
	{
		return kCODoubleType;
	}
	else if ([typeName isEqualToString: @"NSString"])
	{
		return kCOStringType;
	}
	else if ([typeName isEqualToString: @"NSNumber"])
	{
		NSParameterAssert(value == nil || [value isKindOfClass: [NSNumber class]]);

		// TODO: A bit ugly, would be better to add new entity descriptions
		// such as NSBOOLNumber, NSCGFloatNumber etc.
		if (value == nil)
			return kCOStringType;

		if (strcmp([value objCType], @encode(BOOL)) == 0
		 || strcmp([value objCType], @encode(NSInteger)) == 0
		 || strcmp([value objCType], @encode(NSUInteger)) == 0)
		{
			return kCOInt64Type;
		}
		else if (strcmp([value objCType], @encode(CGFloat)) == 0
		      || strcmp([value objCType], @encode(double)) == 0)
		{
			return kCODoubleType;
		}
	}
	else if ([typeName isEqualToString: @"NSData"])
	{
		return kCOBlobType;
	}
	else if ([self isSerializableScalarTypeName: typeName])
	{
		return kCOStringType;
	}
	else
	{
		NSAssert(NO, @"Unsupported serialization type %@ for %@", type, value);
		return 0;
	}
	return 0;
}

- (id)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc value: (id)value
{
	COType type = 0;

	if ([aPropertyDesc isMultivalued])
	{
		if ([aPropertyDesc isOrdered])
		{
			// HACK: The ofValue param should be removed.
			// Should not need to infer type based on an element of the collection.
			COType elementType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
			                                                                 ofValue: [value firstObject]];
			type = (kCOArrayType | elementType);
		}
		else
		{
			COType elementType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
			                                                                 ofValue: [value firstObject]];
			type = (kCOSetType | elementType);
		}
	}
	else
	{
		type = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
		                                                   ofValue: value];
	}
	return [NSNumber numberWithInteger: type];
}

- (id)serializedValueForPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
	id value = nil;

	/* First we try to use the getter named 'serialized' + 'key' */
	
	NSString *capitalizedKey = [[aPropertyDesc name] stringByCapitalizingFirstLetter];
	SEL getter = NSSelectorFromString([@"serialized" stringByAppendingString: capitalizedKey]);
	
	if ([self respondsToSelector: getter])
	{
		value = [self performSelector: getter];
	}
	
	/* If no custom getter can be found, we use PVC which will in last resort
	   access the variable storage with -primitiveValueForKey: */
	
	value = [self valueForProperty: [aPropertyDesc name]];
	
	return [self serializedValueForValue: value];
}

- (COItem *)serializedItem
{
	NSArray *serializedPropertyDescs =
		[[self entityDescription] allPersistentPropertyDescriptions];
	NSMutableDictionary *types =
		[NSMutableDictionary dictionaryWithCapacity: [serializedPropertyDescs count]];
	NSMutableDictionary *values =
		[NSMutableDictionary dictionaryWithCapacity: [serializedPropertyDescs count]];

	for (ETPropertyDescription *propertyDesc in serializedPropertyDescs)
	{
		id value = [self serializedValueForPropertyDescription: propertyDesc];
		[values setObject: value
		           forKey: [propertyDesc name]];
		[types setObject: [self serializedTypeForPropertyDescription: propertyDesc value: value]
		          forKey: [propertyDesc name]];
	}
	
	return [COItem itemWithTypesForAttributes: types valuesForAttributes: values];
}

- (void)setSerializedItem: (COItem *)aSerializedItem
{
	// TODO: Implement
}

@end
