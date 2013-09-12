/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COSerialization.h"
#import "COObject.h"
#import "COObject+RelationshipCache.h"
#import "COItem.h"
#import "COItem+Binary.h"
#import "COObjectGraphContext.h"
#import "COObjectGraphContext+Private.h"
#import "COPath.h"
#import "COPersistentRoot.h"
#import "COEditingContext+Private.h"

#include <objc/runtime.h>

@implementation COObject (COSerialization)

NSString *kCOObjectEntityNameProperty = @"org.etoile-project.coreobject.entityname";

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
	if ([value isKindOfClass: [NSValue class]] == NO)
		return NO;

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
		NSAssert2(NO, @"Unsupported scalar serialization type %s for %@", type, value);
	}
	return nil;
}

- (id)serializedValueForValue: (id)value
{
	if (value == nil)
	{
		return [NSNull null];
	}
	else if ([value isKindOfClass: [ETUUID class]]
             || [value isKindOfClass: [COPath class]])
	{
        return value;
	}
	else if ([value isKindOfClass: [COObject class]])
	{
		/* Some root object relationships are special in the sense the value can be 
		   a core object but its persistency isn't enabled. We interpret these 
		   one-to-one relationships as transient.
		   Usually a root object belongs to some other objects at run-time, in some
		   cases the root object  want to hold a backward pointer (inverse
		   relationship) to those non-persistent object(s).
		   For example, a root object can be a layout item whose parent item is the
		   window group... In such a case, we don't want to persist the window
		   group, but ignore it. At deseserialiation time, the app is responsible
		   to add the item back to the window group (the parent item would be
		   restored then). */
		if ([value isPersistent] || [value objectGraphContext] == [self objectGraphContext])
		{
			if ([value persistentRoot] == [self persistentRoot])
			{
				return [value UUID];
			}
			else
			{
				NSAssert([value isRoot], @"A property must point to a root object "
					"for references accross persistent roots");
				return [COPath pathWithPersistentRoot: [[value persistentRoot] persistentRootUUID]]; // Create path to the current branch by default
			}
		}
		else
		{
			ETAssert([self isRoot]);
			return [NSNull null];
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
		//if (value == nil || ([value persistentRoot] == [self persistentRoot]))
		//{
			return ([aPropertyDesc isComposite] ? kCOTypeCompositeReference : kCOTypeReference);
		//}
		//else
		//{
		//	NSAssert([value isRoot], @"A property must point to a root object "
		//		"for references accross persistent roots");
		//	return kCOTypeReference;
		//}
	}
	else if ([typeName isEqualToString: @"BOOL"]
	      || [typeName isEqualToString: @"NSInteger"]
	      || [typeName isEqualToString: @"NSUInteger"])
	{
		return kCOTypeInt64;
	}
	else if ([typeName isEqualToString: @"CGFloat"]
		 || [typeName isEqualToString: @"Double"])
	{
		return kCOTypeDouble;
	}
	else if ([typeName isEqualToString: @"NSString"])
	{
		return kCOTypeString;
	}
	else if ([typeName isEqualToString: @"NSNumber"])
	{
		NSParameterAssert(value == nil || [value isKindOfClass: [NSNumber class]]);

		// TODO: A bit ugly, would be better to add new entity descriptions
		// such as NSBOOLNumber, NSCGFloatNumber etc.
		if (value == nil)
			return kCOTypeString;

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
	else if ([typeName isEqualToString: @"NSData"])
	{
		return kCOTypeBlob;
	}
	else if ([self isSerializableScalarTypeName: typeName])
	{
		return kCOTypeString;
	}
	else
	{
        // For a case like ETShape.pathResizeSelector,
        // the COObject subclass implements -serializedPathResizeSelector to return an NSString.
        // However, the typeName is "SEL".
        //
        // Not sure of the correct fix.
        // HACK:
        if ([value isKindOfClass: [NSString class]])
        {
            return kCOTypeString;
        }
        
		// FIXME: Don't encode using the keyed archiving unless the property
		// description requires it explicitly.
		//NSAssert(NO, @"Unsupported serialization type %@ for %@", type, value);
		return kCOTypeBlob;
	}
	return 0;
}

- (id)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc value: (id)value
{
	COType type = 0;

	if ([aPropertyDesc isMultivalued])
	{
		NSAssert(value != nil, @"Multivalued properties must not be nil");

		/* Don't serialize CODictionary as multivalue but as COObject reference */
		if ([aPropertyDesc isKeyed])
		{
			NSAssert([value persistentRoot] == [self persistentRoot],
				@"A property must not point on a CODictionary object in another persistent root");

			type = kCOTypeReference;
		}
		else if ([aPropertyDesc isOrdered])
		{
			// HACK: The ofValue param should be removed.
			// Should not need to infer type based on an element of the collection.
			COType elementType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
			                                                                 ofValue: [value firstObject]];
			type = (kCOTypeArray | elementType);
		}
		else
		{
			COType elementType = [self serializedTypeForUnivaluedPropertyDescription: aPropertyDesc
			                                                                 ofValue: [value anyObject]];
			type = (kCOTypeSet | elementType);
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
    /* Check the _relationshipsAsCOPathOrETUUID cache */
    
    id relationship = [_relationshipsAsCOPathOrETUUID objectForKey: [aPropertyDesc name]];
    if (relationship != nil)
    {
        return relationship;
    }
    
	/* First we try to use the getter named 'serialized' + 'key' */
	
	NSString *capitalizedKey = [[aPropertyDesc name] stringByCapitalizingFirstLetter];
	SEL getter = NSSelectorFromString([@"serialized" stringByAppendingString: capitalizedKey]);
	
	if ([self respondsToSelector: getter])
	{
		return [self performSelector: getter];
	}
	
	/* If no custom getter can be found, we try to access the ivar with KVC semantics */

	id value = nil;

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
		                                                                value: value];
	
		[values setObject: serializedValue forKey: [propertyDesc name]];
		[types setObject: serializedType forKey: [propertyDesc name]];
	}
	
    [values setObject: [[self entityDescription] name] forKey: kCOObjectEntityNameProperty];
    [types setObject: [NSNumber numberWithInt: kCOTypeString] forKey: kCOObjectEntityNameProperty];
    
	return [[COItem alloc] initWithUUID: [self UUID]
                      typesForAttributes: types
                     valuesForAttributes: values];
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
		NSAssert2(NO, @"Unsupported scalar serialization type %@ for %@", typeName, value);
	}
	return nil;
}

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
          propertyDescription: (ETPropertyDescription *)aPropertyDesc
{
    if (COTypeIsMultivalued(type))
    {
        if (COTypeMultivaluedPart(type) == kCOTypeArray)
        {
            NSAssert([aPropertyDesc isOrdered] && [aPropertyDesc isMultivalued],
                     @"Serialization type doesn't match metamodel");
            
            id resultCollection = [NSMutableArray array];
            
            for (id subvalue in value)
            {
                id deserializedValue = [self valueForSerializedValue: subvalue
                                                              ofType: COTypePrimitivePart(type)
                                                 propertyDescription: aPropertyDesc];
                
                if (deserializedValue != nil)
                {
                    [resultCollection addObject: deserializedValue];
                }
            }

            // FIXME: Make read-only if needed
            return resultCollection;
        }
        else if (COTypeMultivaluedPart(type) == kCOTypeSet)
        {
            NSAssert([aPropertyDesc isOrdered] == NO && [aPropertyDesc isMultivalued],
                     @"Serialization type doesn't match metamodel");
            
            id resultCollection = [NSMutableSet set];
            
            for (id subvalue in value)
            {
                id deserializedValue = [self valueForSerializedValue: subvalue
                                                              ofType: COTypePrimitivePart(type)
                                                 propertyDescription: aPropertyDesc];
                
                if (deserializedValue != nil)
                {
                    [resultCollection addObject: deserializedValue];
                }
            }
            
            // FIXME: Make read-only if needed
            return resultCollection;
        }
        else
        {
	    NSAssert2(NO, @"Unsupported serialization type %@ for %@", COTypeDescription(type), value);
        }
    }

	if ([value isEqual: [NSNull null]])
	{
		ETAssert(COTypeIsValid(type));
		return nil;
	}

	if (type == kCOTypeReference || type == kCOTypeCompositeReference)
	{
        if (type == kCOTypeCompositeReference)
        {
            NSParameterAssert([value isKindOfClass: [ETUUID class]]);
        }
        else
        {
            NSParameterAssert([value isKindOfClass: [ETUUID class]]
                              || [value isKindOfClass: [COPath class]]);
        }
 	
        id object;
        if ([value isKindOfClass: [ETUUID class]])
        {
            /* Look up a inner object reference in the receiver persistent root */
            object = [[self objectGraphContext] objectReferenceWithUUID: value];
            ETAssert(object != nil);
            
        }
        else /* COPath */
        {
            object = [[[self persistentRoot] parentContext] crossPersistentRootReferenceWithPath: (COPath *)value];
            
            // object may be nil
        }

        if (object != nil)
        {
            /* See also -validateStoreItem: */
            ETAssert([[object entityDescription] isKindOfEntity: [aPropertyDesc type]]
                || [[[object entityDescription]name] isEqualToString: @"CODictionary"]);
        }
		return object;
	}
    else
	{
		NSString *typeName = [[aPropertyDesc type] name];
		
		if (type == kCOTypeInt64 || type == kCOTypeDouble)
		{
			return value;
		}
		else if (type == kCOTypeString)
		{
			if ([self isSerializableScalarTypeName: typeName])
			{
				return [self scalarValueForSerializedValue: value typeName: typeName];
			}
			return value;
		}
		else if (type == kCOTypeBlob)
		{
			NSParameterAssert([value isKindOfClass: [NSData class]]);

			if ([typeName isEqualToString: @"NSData"] == NO)
			{
				return [NSKeyedUnarchiver unarchiveObjectWithData: (NSData *)value];
			}
			return value;
		}
		else
		{
		    NSAssert2(NO, @"Unsupported serialization type %@ for %@", COTypeDescription(type), value);
		}
		return value;
	}
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

/* Validates that the receiver is compatible with the provided store item. */
- (void)validateStoreItem: (COItem *)aStoreItem
{
    if (![[aStoreItem UUID] isEqual: [self UUID]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"-setStoreItem: called with UUID %@ on COObject with UUID %@", [aStoreItem UUID], [self UUID]];
    }

	NSString *entityName = [aStoreItem valueForAttribute: kCOObjectEntityNameProperty];
	ETEntityDescription *entityDesc =
		[[[self objectGraphContext] modelRepository] descriptionForName: entityName];

	/* If B is a subclass of A, and a property description type is A but the 
	   the property value is a B object, the deserialized property value is 
	   accepted because [B isKindOfEntity: A] is true. */
    if (![[self entityDescription] isKindOfEntity: entityDesc] && ![[self entityDescription] isRoot])
    {
		// TODO: Rewrite this exception to provide a better explanation.
        [NSException raise: NSInvalidArgumentException
                    format: @"-setStoreItem: called with entity name %@ on COObject with entity name %@",
                            [aStoreItem valueForAttribute: kCOObjectEntityNameProperty], [[self entityDescription] name]];

    }
}

- (void)setStoreItem: (COItem *)aStoreItem
{
    [self removeCachedOutgoingRelationships];

	[self validateStoreItem: aStoreItem];

	for (NSString *property in [aStoreItem attributeNames])
	{
        if ([property isEqualToString: kCOObjectEntityNameProperty])
        {
            // HACK
            continue;
        }
        
		ETPropertyDescription *propertyDesc =
			[[self entityDescription] propertyDescriptionForName: property];
		id serializedValue = [aStoreItem valueForAttribute: property];
		COType serializedType = [aStoreItem typeForAttribute: property];
	
		if (propertyDesc == nil)
		{
			[NSException raise: NSInvalidArgumentException
			            format: @"Tried to set serialized value %@ of type %@ "
			                     "for property %@ missing in the metamodel %@",
			                    serializedValue, COTypeDescription(serializedType), property, [self entityDescription]];
		}

        // Cache ETUUID / COPath version of relationship
        if ([self isCoreObjectEntityType: [propertyDesc type]])
        {
            if ([serializedValue isKindOfClass: [NSSet class]]
                || [serializedValue isKindOfClass: [NSArray class]])
            {
                serializedValue = [serializedValue mutableCopy];
            }

            [_relationshipsAsCOPathOrETUUID setObject: serializedValue
                                               forKey: property];
        }
        
		id value = [self valueForSerializedValue: serializedValue
		                                  ofType: serializedType
		                     propertyDescription: propertyDesc];
		// TODO: Should change -setSerializedValue:forPropertyDescription: to
		// -setSerializedValue:forProperty: once we remove the previous serialization support
		[self setSerializedValue: value forPropertyDescription: propertyDesc];
	}

	[self awakeFromFetch];
    // TODO: Decide whether to update relationship cache here. Document it.
}

- (id)roundTripValueForProperty: (NSString *)key
{
	ETPropertyDescription *propertyDesc = [[self entityDescription] propertyDescriptionForName: key];
	ETAssert([propertyDesc isPersistent]);
	id value = [self serializedValueForPropertyDescription: propertyDesc];
	id serializedValue = [self serializedValueForValue: value];
	NSNumber *serializedType = [self serializedTypeForPropertyDescription: propertyDesc
	                                                                value: serializedValue];
	
	return [self valueForSerializedValue: serializedValue
	                              ofType: [serializedType intValue]
	                 propertyDescription: [[self entityDescription] propertyDescriptionForName: key]];
}

@end
