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
#import "COPersistentRoot.h"

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

/* Returns a scalar string representation for a NSValue object if possible.
 
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
		// TODO: Add null range support
		return NSStringFromRange([value rangeValue]);
	}
	else
	{
		NSAssert(NO, @"Unsupported scalar serialization type %s for %@", type, value);
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
			return [COPath pathWithPersistentRoot: [[value persistentRoot] persistentRootUUID]
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

// TODO: Could be changed to -serializedValueForProperty: once the previous
// serialization format has been removed.
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
	
	/* If no custom getter can be found, we try to access the ivar with KVC semantics */
	
	if (ETGetInstanceVariableValueForKey(self, &value, [aPropertyDesc name]) == NO)
	{
		/* If no valid ivar can be found, we access the variable storage */
		value = [self primitiveValueForKey: [aPropertyDesc name]];
	}
	return value;
}

- (COItem *)storeItem
{
	NSArray *serializedPropertyDescs =
		[[self entityDescription] allPersistentPropertyDescriptions];
	NSMutableDictionary *types =
		[NSMutableDictionary dictionaryWithCapacity: [serializedPropertyDescs count]];
	NSMutableDictionary *values =
		[NSMutableDictionary dictionaryWithCapacity: [serializedPropertyDescs count]];

	for (ETPropertyDescription *propertyDesc in serializedPropertyDescs)
	{
		// TODO: Should change -serializedValueForPropertyDescription: to
		// -serializedValueForProperty: once we remove the previous serialization support
		id value = [self serializedValueForPropertyDescription: propertyDesc];
		id serializedValue = [self serializedValueForValue: value];
		NSNumber *serializedType = [self serializedTypeForPropertyDescription: propertyDesc
		                                                                value: serializedValue];
	
		[values setObject: serializedValue forKey: [propertyDesc name]];
		[types setObject: serializedType forKey: [propertyDesc name]];
	}
	
	return [COItem itemWithTypesForAttributes: types valuesForAttributes: values];
}

/* Returns a NSValue object for a scalar string value if possible.
 
Nil is returned when the value type is unsupported by CoreObject deserialization. */
- (NSValue *)scalarValueForSerializedValue: (id)value typeName: (NSString *)typeName
{
	// NOTE: We should never receive a nil value, because scalar values are
	// either special zero or null constants encoded as such but never equal to
	// zero or nil.
	NSParameterAssert(value != nil);
	NSParameterAssert([value isKindOfClass: [NSString class]]);

	if ([typeName isEqualToString: @"NSPoint"])
	{
		NSPoint point;
		if ([value isEqualToString: @"null-point"])
		{
			point = CONullPoint;
		}
		else
		{
			point = NSPointFromString(value);
		}
		return [NSValue valueWithPoint: point];
	}
	else if ([typeName isEqualToString: @"NSSize"])
	{
		NSSize size;
		if ([value isEqualToString: @"null-size"])
		{
			size = CONullSize;
		}
		else
		{
			size = NSSizeFromString(value);
		}
		return [NSValue valueWithSize: size];
	}
	else if ([typeName isEqualToString: @"NSRect"])
	{
		NSRect rect;
		if ([value isEqualToString: @"null-rect"])
		{
			rect = CONullRect;
		}
		else
		{
			rect = NSRectFromString(value);
		}
		return [NSValue valueWithRect: rect];
	}
	else if ([typeName isEqualToString: @"NSRange"])
	{
		// TODO: Add null range support
		return [NSValue valueWithRange: NSRangeFromString(value)];
	}
	else
	{
		NSAssert(NO, @"Unsupported scalar serialization type %@ for %@", typeName, value);
	}
	return nil;
}

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
          propertyDescription: (ETPropertyDescription *)aPropertyDesc
{
	if (type == kCOReferenceType)
	{
		NSParameterAssert([value isKindOfClass: [ETUUID class]]);

		if (value == nil)
			return nil;

		return [[[self persistentRoot] parentContext] objectWithUUID: value
														  entityName: [[aPropertyDesc type] name]
														  atRevision: nil];
	}
	else if (type == kCOArrayType)
	{
		NSAssert([aPropertyDesc isOrdered] && [aPropertyDesc isMultivalued],
			@"Serialization type doesn't match metamodel");

		// TODO: Allocating a C array on the stack is probably premature
		// optimization. Fast enumeration could even be faster.
		NSUInteger count = [value count];
		id mappedObjects[count];

		for (int i = 0; i < count; i++)
		{
			mappedObjects[i] = [self valueForSerializedValue: [value objectAtIndex: i]
													  ofType: COPrimitiveType(type)
			                             propertyDescription: aPropertyDesc];
		}

		Class arrayClass = ([aPropertyDesc isReadOnly] ? [NSArray class] : [NSMutableArray class]);
		return [arrayClass arrayWithObjects: mappedObjects count: count];
	}
	else if (type == kCOSetType)
	{
		NSAssert([aPropertyDesc isOrdered] == NO && [aPropertyDesc isMultivalued],
			@"Serialization type doesn't match metamodel");

		// TODO: Allocating a C array on the stack is probably premature
		// optimization. Fast enumeration could even be faster.
		NSUInteger count = [value count];
		id mappedObjects[count];

		for (int i = 0; i < count; i++)
		{
			mappedObjects[i] = [self valueForSerializedValue: [value objectAtIndex: i]
													  ofType: COPrimitiveType(type)
			                             propertyDescription: aPropertyDesc];
		}

		Class setClass = ([aPropertyDesc isReadOnly] ? [NSSet class] : [NSMutableSet class]);
		return [setClass setWithObjects: mappedObjects count: count];
	}
	else if (COTypeIsPrimitive(type))
	{
		NSString *typeName = [[aPropertyDesc type] name];
	
		if ([self isSerializableScalarTypeName: typeName])
		{
			return [self scalarValueForSerializedValue: value typeName: typeName];
		}
		else if (type == kCOBlobType && [typeName isEqualToString: @"NSData"])
		{
			if (value == nil)
				return nil;

			NSParameterAssert([value isKindOfClass: [NSData class]]);
			return [NSKeyedUnarchiver unarchiveObjectWithData: (NSData *)value];
		}
		return value;
	}
	else
	{
		NSAssert(NO, @"Unsupported serialization type %@ for %@", @(type), value);
	}
	return nil;
}

// TODO: Could be changed to -setSerializedValue:forProperty: once the previous
// serialization format has been removed.
- (void)setSerializedValue: (id)value forPropertyDescription: (ETPropertyDescription *)aPropertyDesc
{
	NSString *key = [aPropertyDesc name];

	/* First we try to use the setter named 'setSerialized' + 'key' */

	SEL setter = NSSelectorFromString([NSString stringWithFormat: @"%@%@%@", 
		@"setSerialized", [key stringByCapitalizingFirstLetter], @":"]);

	if ([self respondsToSelector: setter])
	{
		[self performSelector: setter withObject: value];
		return;
	}	
	
	/* When no custom setter can be found, we try to access the ivar with KVC semantics */

	[self willChangeValueForProperty: key];

	if (ETSetInstanceVariableValueForKey(self, value, key) == NO)
	{
		/* If no valid ivar can be found, we access the variable storage */
		[self setPrimitiveValue: value forKey: key];
	}

	/* Persistent roots will post KVO notifications but won't record the changes */
	[self didChangeValueForProperty: key];
}
								
- (void)setStoreItem: (COItem *)aStoreItem
{
	for (NSString *property in [aStoreItem attributeNames])
	{
		ETPropertyDescription *propertyDesc =
			[[self entityDescription] propertyDescriptionForName: property];
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
		// TODO: Should change -setSerializedValue:forPropertyDescription: to
		// -setSerializedValue:forProperty: once we remove the previous serialization support
		[self setSerializedValue: value forPropertyDescription: propertyDesc];
	}
}

@end
