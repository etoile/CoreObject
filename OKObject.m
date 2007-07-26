/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "OKObject.h"
#import "OKMultiValue.h"
#import "OKUUID.h"
#import "GNUstep.h"

static NSMutableDictionary *propertyTypes;

NSString *kOKUIDProperty = @"kOKUIDProperty";
NSString *kOKCreationDateProperty = @"kOKCreationDateProperty";
NSString *kOKModificationDateProperty = @"kOKModificationDateProperty";
NSString *kOKReadOnlyProperty = @"kOKReadOnlyProperty";
NSString *kOKParentsProperty = @"kOKParentsProperty";
NSString *kOKTagProperty = @"kOKTagProperty";

NSString *qOKTextContent = @"qOKTextContent";

/* For property list */
NSString *pOKClassKey = @"Class";
NSString *pOKPropertiesKey = @"Properties";
NSString *pOKValuesKey = @"Values";
NSString *pOKVersionKey = @"Version";
NSString *pOKVersion1Value = @"OKVersion1";

@implementation OKObject
/* Private */

/* Return all text for search */
- (NSString *) _textContent
{
	NSMutableString *text = [[NSMutableString alloc] init];
	NSEnumerator *e = [[[self class] properties] objectEnumerator];
	NSString *property = nil;
	while ((property = [e nextObject]))
	{
		OKPropertyType type = [[self class] typeOfProperty: property];
		switch(type)
		{
			case kOKStringProperty:
			case kOKArrayProperty:
			case kOKDictionaryProperty:
				[text appendFormat: @"%@ ", [[self valueForProperty: property] description]];
				break;
			case kOKMultiStringProperty:
			case kOKMultiArrayProperty:
			case kOKMultiDictionaryProperty:
				{
					OKMultiValue *mv = [self valueForProperty: property];
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

	if ((object = [propertyList objectForKey: pOKPropertiesKey]))
		[[self class] addPropertiesAndTypes: object];

	if ((object = [propertyList objectForKey: pOKValuesKey]))
	{
		/* Check OKMultiValue */
		NSMutableDictionary *dict = [(NSDictionary *) object mutableCopy];
		NSEnumerator *e = [[dict allKeys] objectEnumerator];
		NSString *key = nil;
		while ((key = [e nextObject]))
		{
			if ([[self class] typeOfProperty: key] & kOKMultiValueMask)
			{
				OKMultiValue *mv = [[OKMultiValue alloc] initWithPropertyList: [dict objectForKey: key]];
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

+ (OKPropertyType) typeOfProperty: (NSString *) property
{
	if (propertyTypes == nil)
		return kOKErrorInProperty;

	NSDictionary *dict = [propertyTypes objectForKey: NSStringFromClass([self class])];
	if (dict == nil)
	{
		return kOKErrorInProperty;
	}

	NSNumber *type = [dict objectForKey: property];
	if (type)
		return [type intValue];
	else
		return kOKErrorInProperty;
}

+ (id) objectWithPropertyList: (NSDictionary *) propertyList
{
	id object = nil;
	if ((object = [propertyList objectForKey: pOKClassKey]) &&
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
	NSString *v = [propertyList objectForKey: pOKVersionKey];
	if ([v isEqualToString: pOKVersion1Value])
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
	NSMutableDictionary *dict;

	[pl setObject: NSStringFromClass([self class]) forKey: pOKClassKey];
	[pl setObject: [[self class] propertiesAndTypes] 
	       forKey: pOKPropertiesKey];

	dict = [_properties mutableCopy];
	/* We remove parents property */
	[dict removeObjectForKey: kOKParentsProperty];
	/* If we have OKMultiValue, save its property list */
	NSEnumerator *e = [[dict allKeys] objectEnumerator];
	NSString *key = nil;
	while ((key = [e nextObject]))
	{
		id value = [dict objectForKey: key];
		if ([value isKindOfClass: [OKMultiValue class]])
		{
			[dict setObject: [(OKMultiValue *)value propertyList]
			         forKey: key];
		}
	}
	[pl setObject: dict forKey: pOKValuesKey];
	[pl setObject: pOKVersion1Value forKey: pOKVersionKey];
	return AUTORELEASE(pl);
}

- (BOOL) removeValueForProperty: (NSString *) property
{
	if ([self isReadOnly])
		return NO;

	[_properties removeObjectForKey: property];
	[self setValue: [NSDate date] forProperty: kOKModificationDateProperty];
    [_nc postNotificationName: kOKObjectChangedNotification
         object: self
	     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
	                 property, kOKRemovedProperty, nil]];
	return YES;
}

- (BOOL) setValue: (id) value forProperty: (NSString *) property
{
	if ([self isReadOnly])
		return NO;

	[_properties setObject: value forKey: property];
	[_properties setObject: [NSDate date] 
	                forKey: kOKModificationDateProperty];
    [_nc postNotificationName: kOKObjectChangedNotification
         object: self
	     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
	                 property, kOKUpdatedProperty, nil]];
	return YES;
}

- (id) valueForProperty: (NSString *) property
{
	return [_properties objectForKey: property];
}

- (NSArray *) parentGroups
{
    NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
    NSArray *value = [self valueForProperty: kOKParentsProperty];
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
	return ([[self valueForProperty: kOKReadOnlyProperty] intValue] == 1);
}

- (NSString *) uniqueID
{
	return [self valueForProperty: kOKUIDProperty];
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

/* NSObject */
+ (void) initialize
{
	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			kOKUIDProperty,
		[NSNumber numberWithInt: kOKDateProperty], 
			kOKCreationDateProperty,
		[NSNumber numberWithInt: kOKDateProperty], 
			kOKModificationDateProperty,
		[NSNumber numberWithInt: kOKIntegerProperty], 
			kOKReadOnlyProperty,
		[NSNumber numberWithInt: kOKArrayProperty], 
			kOKParentsProperty,
		[NSNumber numberWithInt: kOKArrayProperty], 
			kOKTagProperty,
		nil];
	[OKObject addPropertiesAndTypes: pt];
	DESTROY(pt);
}

- (id) init
{
	self = [super init];
	_properties = [[NSMutableDictionary alloc] init];
	[self setValue: [NSNumber numberWithInt: 0] 
	      forProperty: kOKReadOnlyProperty];
	[self setValue: [NSString UUIDString]
	      forProperty: kOKUIDProperty];
	[self setValue: [NSDate date]
	      forProperty: kOKCreationDateProperty];
	[self setValue: [NSDate date]
	      forProperty: kOKModificationDateProperty];
    [self setValue: AUTORELEASE([[NSMutableArray alloc] init])
          forProperty: kOKParentsProperty];
	_nc = [NSNotificationCenter defaultCenter];
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
- (unsigned long) hash
{
	return [[self valueForProperty: kOKUIDProperty] hash];
}

- (BOOL) isEqual: (OKObject *) other
{
	if (other && [other isKindOfClass: [self class]])
	{
		return [[self valueForProperty: kOKUIDProperty] isEqual: [other valueForProperty: kOKUIDProperty]];
	}
	return NO;
}

/* NSCopying */
- (id) copyWithZone: (NSZone *) zone
{
	OKObject *clone = [[[self class] allocWithZone: zone] init];
	clone->_properties = [_properties mutableCopyWithZone: zone];
	return clone;
}

/* KVC */
- (id) valueForKey: (NSString *) key
{
	/* Intercept query property */
	if ([key isEqualToString: qOKTextContent])
	{
		return [self _textContent];
	}
	return [self valueForProperty: key];
}

- (id) valueForKeyPath: (NSString *) key
{
	/* Intercept query property */
	if ([key isEqualToString: qOKTextContent])
	{
		return [self _textContent];
	}

	NSArray *keys = [key componentsSeparatedByString: @"."];
	if ([keys count])
	{
		id value = [self valueForProperty: [keys objectAtIndex: 0]];
		if ([value isKindOfClass: [OKMultiValue class]])
		{
			OKMultiValue *mv = (OKMultiValue *) value;
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

NSString *kOKObjectChangedNotification = @"kOKObjectChangedNotification";
NSString *kOKUpdatedProperty = @"kOKUpdatedProperty";
NSString *kOKRemovedProperty = @"kOKRemovedProperty";

