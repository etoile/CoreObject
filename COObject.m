/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <strings.h>
#import "COObject.h"
#import "COMultiValue.h"
#import "COObjectContext.h"
#import "NSObject+CoreObject.h"
#import "GNUstep.h"

static NSMutableDictionary *propertyTypes;

NSString *kCOUIDProperty = @"kCOUIDProperty";
NSString *kCOVersionProperty = @"kCOVersionProperty";
NSString *kCOCreationDateProperty = @"kCOCreationDateProperty";
NSString *kCOModificationDateProperty = @"kCOModificationDateProperty";
NSString *kCOReadOnlyProperty = @"kCOReadOnlyProperty";
NSString *kCOParentsProperty = @"kCOParentsProperty";
NSString *kCOTagProperty = @"kCOTagProperty";

NSString *qCOTextContent = @"qCOTextContent";

/* For property list */
NSString *pCOClassKey = @"Class";
NSString *pCOPropertiesKey = @"Properties";
NSString *pCOValuesKey = @"Values";
NSString *pCOVersionKey = @"Version";
NSString *pCOVersion1Value = @"COVersion1";


@implementation COObject
/* Private */

/* Return all text for search */
- (NSString *) _textContent
{
	NSMutableString *text = [[NSMutableString alloc] init];
	NSEnumerator *e = [[[self class] properties] objectEnumerator];
	NSString *property = nil;
	while ((property = [e nextObject]))
	{
		COPropertyType type = [[self class] typeOfProperty: property];
		switch(type)
		{
			case kCOStringProperty:
			case kCOArrayProperty:
			case kCODictionaryProperty:
				[text appendFormat: @"%@ ", [[self valueForProperty: property] description]];
				break;
			case kCOMultiStringProperty:
			case kCOMultiArrayProperty:
			case kCOMultiDictionaryProperty:
				{
					COMultiValue *mv = [self valueForProperty: property];
					int i, count = [mv count];
					for (i = 0; i < count; i++)
					{
						[text appendFormat: @"%@ ", [[mv valueAtIndex: i] description]];
					}
				}
				break;
			default:
				continue;
		}
	}
	return AUTORELEASE(text);
}

- (void) _readObjectVersion1: (NSDictionary *) propertyList
{
	/* We ignore class here because class is decided before this method */
	id object = nil;

	if ((object = [propertyList objectForKey: pCOPropertiesKey]))
		[[self class] addPropertiesAndTypes: object];

	if ((object = [propertyList objectForKey: pCOValuesKey]))
	{
		/* Check COMultiValue */
		NSMutableDictionary *dict = [(NSDictionary *) object mutableCopy];
		NSEnumerator *e = [[dict allKeys] objectEnumerator];
		NSString *key = nil;
		while ((key = [e nextObject]))
		{
			if ([[self class] typeOfProperty: key] & kCOMultiValueMask)
			{
				COMultiValue *mv = [[COMultiValue alloc] initWithPropertyList: [dict objectForKey: key]];
				[dict setObject: mv forKey: key];
				DESTROY(mv);
			}
		}
		[_properties addEntriesFromDictionary: dict];
		DESTROY(dict); /* mutable copied above */
	}
}

/* End of Private */

+ (int) addPropertiesAndTypes: (NSDictionary *) properties
{
	if (propertyTypes == nil)
	{
		propertyTypes = [[NSMutableDictionary alloc] init];
	}

	NSMutableDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		dict = [[NSMutableDictionary alloc] init];
		[propertyTypes setObject: dict forKey: NSStringFromClass([self class])];
		RELEASE(dict);
	}
	int i, count;
	NSArray *allKeys = [properties allKeys];
	NSArray *allValues = [properties allValues];
	count = [allKeys count];
	for (i = 0; i < count; i++)
	{
		[dict setObject: [allValues objectAtIndex: i]
		      forKey: [allKeys objectAtIndex: i]];
	}
	return count;
}

+ (NSDictionary *) propertiesAndTypes
{
	return [propertyTypes objectForKey: NSStringFromClass([self class])];
}

+ (NSArray *) properties
{
	if (propertyTypes == nil)
		return nil;

	NSDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
		return nil;

	return [dict allKeys];
}

+ (int) removeProperties: (NSArray *) properties
{
	if (propertyTypes == nil)
		return 0;
	NSMutableDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		return 0;
	}
	NSEnumerator *e = [properties objectEnumerator];
	NSArray *allKeys = [dict allKeys];
	NSString *key = nil;
	int count = 0;
	while ((key = [e nextObject]))
	{
		if ([allKeys containsObject: key])
		{
			[dict removeObjectForKey: key];
			count++;
		}
	}
	return count;
}

+ (COPropertyType) typeOfProperty: (NSString *) property
{
	if (propertyTypes == nil)
		return kCOErrorInProperty;

	NSDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		return kCOErrorInProperty;
	}

	NSNumber *type = [dict objectForKey: property];
	if (type)
		return [type intValue];
	else
		return kCOErrorInProperty;
}

+ (id) objectWithPropertyList: (NSDictionary *) propertyList
{
	id object = nil;
	if ((object = [propertyList objectForKey: pCOClassKey]) &&
	    ([object isKindOfClass: [NSString class]]))
	{
		Class oClass = NSClassFromString((NSString *)object);
		return AUTORELEASE([[oClass alloc] initWithPropertyList: propertyList]);
	}
	return nil;
}

- (id) initWithPropertyList: (NSDictionary *) propertyList
{
	self = [self init];
	if ([propertyList isKindOfClass: [NSDictionary class]] == NO)
	{
		NSLog(@"Error: Not a valid property list: %@", propertyList);
		[self dealloc];
		return nil;
	}
	/* Let check version */
	NSString *v = [propertyList objectForKey: pCOVersionKey];
	if ([v isEqualToString: pCOVersion1Value])
	{
		[self _readObjectVersion1: propertyList];
	}
	else
	{
		NSLog(@"Unknown version %@", v);
		[self dealloc];
		return nil;
	}

	return self;
}

- (NSMutableDictionary *) propertyList
{
	NSMutableDictionary *pl = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *dict = nil;
	//NSMutableDictionary *relations = [[NSMutableDictionary alloc] init];

	[pl setObject: NSStringFromClass([self class]) forKey: pCOClassKey];
	[pl setObject: [[self class] propertiesAndTypes] 
	       forKey: pCOPropertiesKey];

	dict = [_properties mutableCopy];
	/* We remove parents property */
	[dict removeObjectForKey: kCOParentsProperty];
	/* If we have COMultiValue, save its property list */
	NSEnumerator *e = [[dict allKeys] objectEnumerator];
	NSString *key = nil;
	while ((key = [e nextObject]))
	{
		id value = [dict objectForKey: key];
		if ([value isKindOfClass: [COMultiValue class]])
		{
			[dict setObject: [(COMultiValue *)value propertyList]
			         forKey: key];
		}
#if 0
		else if ([value isManagedCoreObject]) // has UUID and URL
		{
			[relations setObject: value forKey: [value UUID]];
			[dict setObject: [value UUID] forKey: key];
		}
		else if ([value isCoreObject]) // has URL
		{
			[relations setObject: value forKey: [value URL]];
			[dict setObject: [value URL] forKey: key];
		}
#endif
	}
	[pl setObject: dict forKey: pCOValuesKey];
	[pl setObject: pCOVersion1Value forKey: pCOVersionKey];
	return AUTORELEASE(pl);
}

- (COObjectContext *) objectContext
{
	return _objectContext;
}

- (NSDictionary *) relatedCoreObjects
{
//	NSDictionary *properties = [self propertyList];
	NSMutableDictionary *relations = [NSMutableDictionary dictionary];
#if 0
	/* We remove parents property */
	[properties removeObjectForKey: kCOParentsProperty];
	/* If we have COMultiValue, save its property list */
	NSEnumerator *e = [[properties allKeys] objectEnumerator];
	NSString *key = nil;
	while ((key = [e nextObject]))
	{
		id value = [dict objectForKey: key];
		if ([value isKindOfClass: [COMultiValue class]])
		{
			[properties setObject: [(COMultiValue *)value propertyList]
			               forKey: key];
		}
		else if ([value isManagedCoreObject]) // has UUID and URL
		{
			[relations setObject: value forKey: [value UUID]];
			[dict setObject: [value UUID] forKey: key];
		}
		else if ([value isCoreObject]) // has URL
		{
			[relations setObject: value forKey: [value URL]];
			[dict setObject: [value URL] forKey: key];
		}
	}
#endif
	return relations;
}

- (void) loadRelatedCoreObjects: (NSDictionary *)relations
{

}

- (void) storeRelatedCoreObjects: (NSDictionary *)relations
{

}

/** Returns the properties published by the receiver and accessible through 
	Property Value Coding. The returned array includes the properties inherited 
	from the superclass too (see -[NSObject properties]). */
- (NSArray *) properties
{
	return [[super properties] arrayByAddingObjectsFromArray: [[self class] properties]];
}

- (BOOL) removeValueForProperty: (NSString *) property
{
	if (IGNORE_CHANGES || [self isReadOnly])
		return NO;

	RECORD(property)
	[_properties removeObjectForKey: property];
	[self setValue: [NSDate date] forProperty: kCOModificationDateProperty];
    [_nc postNotificationName: kCOObjectChangedNotification
         object: self
	     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
	                 property, kCORemovedProperty, nil]];
	END_RECORD

	return YES;
}

- (BOOL) setValue: (id) value forProperty: (NSString *) property
{
	if (IGNORE_CHANGES || [self isReadOnly])
		return NO;

	RECORD(value, property)
	[_properties setObject: value forKey: property];
	[_properties setObject: [NSDate date] 
	                forKey: kCOModificationDateProperty];
    [_nc postNotificationName: kCOObjectChangedNotification
         object: self
	     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
	                 property, kCOUpdatedProperty, nil]];
	END_RECORD

	return YES;
}

- (id) valueForProperty: (NSString *) property
{
	return [_properties objectForKey: property];
}

- (NSArray *) parentGroups
{
    NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
    NSArray *value = [self valueForProperty: kCOParentsProperty];
    if (value)
    {
        [set addObjectsFromArray: value];

        int i, count = [value count];
        for (i = 0; i < count; i++)
        {
            [set addObjectsFromArray: [[value objectAtIndex: i] parentGroups]];
        }
    }
    return [set allObjects];
}

- (BOOL) isReadOnly
{	
	return ([[self valueForProperty: kCOReadOnlyProperty] intValue] == 1);
}

// TODO: Modify COObject to only rely on it and removes -uniqueID
- (ETUUID *) UUID
{	return AUTORELEASE([[ETUUID alloc] initWithString: [self valueForProperty: kCOUIDProperty]]);
}

- (NSString *) uniqueID
{
	return [self valueForProperty: kCOUIDProperty];
}

static BOOL automaticPersistency = NO;

+ (BOOL) automaticallyMakeNewInstancesPersistent
{
	return automaticPersistency;
}

+ (void) setAutomaticallyMakeNewInstancesPersistent: (BOOL)flag
{
	automaticPersistency = flag;
}

- (BOOL) isPersistent
{
	return ([self objectVersion] > -1);
}

/** Returns the version of the object format, plays a role similar to class 
    versioning provided by +[NSObject version]. */
- (int) version
{
	return [(NSNumber *)[self valueForProperty: kCOVersionProperty] intValue];
}

- (void) _setObjectVersion: (int)version
{
	ETDebugLog(@"Setting version from %d to %d of %@", _objectVersion, version, self);
	_objectVersion = version;
}

/** Returns the current version of the instance. This version represents a 
    revision in the object history. 
    The returned value is comprised between 0 (base version created on first 
    serialization) and the last object version which can be known by calling 
    -lastObjectVersion. */
- (int) objectVersion
{
	return _objectVersion;
}

- (int) lastObjectVersion
{
	// TODO: Implement 
	return 0;
}

- (BOOL) save
{
	int prevVersion = [self objectVersion];
	[[self objectContext] snapshotObject: self];
	return ([self objectVersion] > prevVersion);
}

- (BOOL) isCopyPromise
{
	return NO;
}

// FIXME: Implement
- (NSDictionary *) metadatas
{
	return nil;
}

- (BOOL) matchesPredicate: (NSPredicate *) predicate
{
	BOOL result = NO;
	if ([predicate isKindOfClass: [NSCompoundPredicate class]])
	{
		NSCompoundPredicate *cp = (NSCompoundPredicate *) predicate;
		NSArray *subs = [cp subpredicates];
		int i, count = [subs count];
		switch ([cp compoundPredicateType])
		{
			case NSNotPredicateType:
				result = ![self matchesPredicate: [subs objectAtIndex: 0]];
				break;
			case NSAndPredicateType:
				result = YES;
				for (i = 0; i < count; i++)
				{
					result = result && [self matchesPredicate: [subs objectAtIndex: i]];
				}
				break;
			case NSOrPredicateType:
				result = NO;
				for (i = 0; i < count; i++)
				{
					result = result || [self matchesPredicate: [subs objectAtIndex: i]];
				}
				break;
			default: 
				NSLog(@"Error: Unknown compound predicate type");
		}
	}
	else if ([predicate isKindOfClass: [NSComparisonPredicate class]])
	{
		NSComparisonPredicate *cp = (NSComparisonPredicate *) predicate;
		id lv = [[cp leftExpression] expressionValueWithObject: self context: nil];
		id rv = [[cp rightExpression] expressionValueWithObject: self context: nil];
		NSArray *array = nil;
		if ([lv isKindOfClass: [NSArray class]] == NO)
		{
			array = [NSArray arrayWithObjects: lv, nil];
		}
		else
		{
			array = (NSArray *) lv;
		}
		NSEnumerator *e = [array objectEnumerator];
		id v = nil;
		while ((v = [e nextObject]))
		{
			switch ([cp predicateOperatorType])
			{
				case NSLessThanPredicateOperatorType:
					return ([v compare: rv] == NSOrderedAscending);
				case NSLessThanOrEqualToPredicateOperatorType:
					return ([v compare: rv] != NSOrderedDescending);
				case NSGreaterThanPredicateOperatorType:
				return ([v compare: rv] == NSOrderedDescending);
				case NSGreaterThanOrEqualToPredicateOperatorType:
					return ([v compare: rv] != NSOrderedAscending);
				case NSEqualToPredicateOperatorType:
					return [v isEqual: rv];
				case NSNotEqualToPredicateOperatorType:
					return ![v isEqual: rv];
				case NSMatchesPredicateOperatorType:
					{
						// FIXME: regular expression
						return NO;
					}
				case NSLikePredicateOperatorType:
					{
						// FIXME: simple regular expression
						return NO;
					}
				case NSBeginsWithPredicateOperatorType:
					return [[v description] hasPrefix: [rv description]];
				case NSEndsWithPredicateOperatorType:
					return [[v description] hasSuffix: [rv description]];
				case NSInPredicateOperatorType:
					// NOTE: it is the reverse CONTAINS
					return ([[rv description] rangeOfString: [v description]].location != NSNotFound);;
				case NSCustomSelectorPredicateOperatorType:
					{
						// FIXME: use NSInvocation
						return NO;
					}
				default:
					NSLog(@"Error: Unknown predicate operator");
			}
		}
	}
	return result;
}

/** If you want to create a subclass of a CoreObject data model class, you 
    should declare the new properties and types of the class by creating a 
    dictionary with types as objects and keys as properties, then calls 
    +addPropertiesAndTypes: with this dictionary as parameter.
    Each type must be a NSNumber initialized with one of the type constants 
    defined in COPropertyType.h. Each property must be a string that uniquely 
    identify the property by its name, and whose name doesn't collide with a 
    property inherited from superclasses. For properties, you typically declare 
    your owns as string constants with an identifier name prefixed by 'k' and
    suffixed by 'Property'. For example, see COObject.h which exposes all 
    properties of the COObject data model class.
    When you create a subclass of COObject or some other subclasses such as 
    COGroup, you  must first call +initalize on your superclass to get all 
    inherited properties and types registered for your subclass. This only holds 
    for the GNU runtime though, and may change in future if CoreObject was 
    ported to another runtime. */
+ (void) initialize
{
	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			kCOUIDProperty,
		[NSNumber numberWithInt: kCOIntegerProperty], 
			kCOVersionProperty,
		[NSNumber numberWithInt: kCODateProperty], 
			kCOCreationDateProperty,
		[NSNumber numberWithInt: kCODateProperty], 
			kCOModificationDateProperty,
		[NSNumber numberWithInt: kCOIntegerProperty], 
			kCOReadOnlyProperty,
		[NSNumber numberWithInt: kCOArrayProperty], 
			kCOParentsProperty,
		[NSNumber numberWithInt: kCOArrayProperty], 
			kCOTagProperty,
		nil];
	[self addPropertiesAndTypes: pt];
	DESTROY(pt);
}

- (id) init
{
	self = [super init];
	_properties = [[NSMutableDictionary alloc] init];
	[self setValue: [NSNumber numberWithInt: 0] 
	      forProperty: kCOReadOnlyProperty];
	[self setValue: [NSString UUIDString]
	      forProperty: kCOUIDProperty];
	[self setValue: [NSNumber numberWithInt: 0]
	      forProperty: kCOVersionProperty];
	[self setValue: [NSDate date]
	      forProperty: kCOCreationDateProperty];
	[self setValue: [NSDate date]
	      forProperty: kCOModificationDateProperty];
    [self setValue: AUTORELEASE([[NSMutableArray alloc] init])
          forProperty: kCOParentsProperty];
	_nc = [NSNotificationCenter defaultCenter];
	/* We get the object context at the end, hence all the previous calls are 
	   not serialized by RECORD in -setValue:forProperty: 
	   FIXME: Should be obtained by parameter usually. */
	_objectContext = [COObjectContext defaultContext];
	_objectVersion = -1;
	return self;
}

- (void) dealloc
{
	DESTROY(_properties);
	[super dealloc];
}
#if 0 // Crash due the recursive back to parent group.
- (NSString *) description
{
	return [_properties description];
}
#endif
- (unsigned int) hash
{
	return [[self valueForProperty: kCOUIDProperty] hash];
}

- (BOOL) isEqual: (id) other
{
	if (other && [other isKindOfClass: [self class]])
	{
		return [[self valueForProperty: kCOUIDProperty] isEqual: [other valueForProperty: kCOUIDProperty]];
	}
	return NO;
}

/* Serialization (EtoileSerialize) */

- (BOOL) serialize: (char *)aVariable using: (ETSerializer *)aSerializer
{
	if (strcmp(aVariable, "_nc") == 0
	 || strcmp(aVariable, "_objectContext") == 0
	 || strcmp(aVariable, "_objectVersion") == 0)
	{
		return YES; /* Should not be automatically serialized (manual) */
	}

	return NO; /* Serializer handles the ivar */
}

- (void *) deserialize: (char *)aVariable 
           fromPointer: (void *)aBlob 
               version: (int)aVersion
{
	if (strcmp(aVariable, "_nc") == 0)
	{
		_nc = [NSNotificationCenter defaultCenter];
		return MANUAL_DESERIALIZE;
	}
	else if (strcmp(aVariable, "_objectContext") == 0)
	{
		_objectContext = [COObjectContext defaultContext];
		return MANUAL_DESERIALIZE;
	}

	return AUTO_DESERIALIZE;
}

- (void) deserializerDidFinish: (ETDeserializer *)deserializer forVersion: (int)objectVersion
{
	NSLog(@"Finished deserialization of %@ to object version %d", self, objectVersion);
	_objectVersion = objectVersion;
}

- (void) serializerDidFinish: (ETSerializer *)serializer forVersion: (int)objectVersion
{
	_objectVersion = objectVersion;
}

/* NSCopying */
- (id) copyWithZone: (NSZone *) zone
{
	COObject *clone = [[[self class] allocWithZone: zone] init];
	clone->_properties = [_properties mutableCopyWithZone: zone];
	return clone;
}

/* KVC */
- (id) valueForKey: (NSString *) key
{
	/* Intercept query property */
	if ([key isEqualToString: qCOTextContent])
	{
		return [self _textContent];
	}
	return [self valueForProperty: key];
}

- (id) valueForKeyPath: (NSString *) key
{
	/* Intercept query property */
	if ([key isEqualToString: qCOTextContent])
	{
		return [self _textContent];
	}

	NSArray *keys = [key componentsSeparatedByString: @"."];
	if ([keys count])
	{
		id value = [self valueForProperty: [keys objectAtIndex: 0]];
		if ([value isKindOfClass: [COMultiValue class]])
		{
			COMultiValue *mv = (COMultiValue *) value;
			int i, count = [mv count];
			NSMutableArray *array = [[NSMutableArray alloc] init];
			if ([keys count] > 1)
			{
				/* Find the label first */
				NSString *label = [keys objectAtIndex: 1];
				for (i = 0; i < count; i++)
				{
					if ([[mv labelAtIndex: i] isEqualToString: label])
					{
						[array addObject: [mv valueAtIndex: i]];
					}
				}
			}
			else
			{
				/* Search all labels */
				for (i = 0; i < count; i++)
				{
					[array addObject: [mv valueAtIndex: i]];
				}
			}
			return AUTORELEASE(array);
		}
	}
	return [self valueForKey: key];
}

@end

NSString *kCOObjectChangedNotification = @"kCOObjectChangedNotification";
NSString *kCOUpdatedProperty = @"kCOUpdatedProperty";
NSString *kCORemovedProperty = @"kCORemovedProperty";

