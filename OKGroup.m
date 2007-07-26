/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "OKGroup.h"
#import "OKMultiValue.h"
#import "GNUstep.h"

NSString *kOKGroupNameProperty = @"kOKGroupNameProperty";
NSString *kOKGroupChildrenProperty = @"kOKGroupChildrenProperty";
NSString *kOKGroupSubgroupsProperty = @"kOKGroupSubgroupsProperty";

NSString *pOKAllObjectsKey = @"AllObjects";
NSString *pOKAllClassesKey = @"AllClasses";
NSString *pOKAllGroupsKey = @"AllGroups";

NSString *kOKGroupAddObjectNotification = @"kOKGroupAddObjectNotification";
NSString *kOKGroupRemoveObjectNotification = @"kOKGroupRemoveObjectNotification";
NSString *kOKGroupAddSubgroupNotification = @"kOKGroupAddSubgroupNotification";
NSString *kOKGroupRemoveSubgroupNotification = @"kOKGroupRemoveSubgroupNotification";
NSString *kOKGroupChild = @"kOKGroupChild";

@implementation OKGroup
/* Private */
- (void) _addAsParent: (OKObject *) object
{
	NSMutableArray *a = [object valueForProperty: kOKParentsProperty];
	if (a == nil)
	{
		a = AUTORELEASE([[NSMutableArray alloc] init]);
		[object setValue: a forProperty: kOKParentsProperty];
	}
	[a addObject: self];
}

- (void) _removeAsParent: (OKObject *) object
{
	NSMutableArray *a = [object valueForProperty: kOKParentsProperty];
	if (a)
	{
		[a removeObject: self];
	}
}

- (void) _readGroupVersion1: (NSDictionary *) propertyList
{
	CREATE_AUTORELEASE_POOL(x);

	/* Generate all classes */
	NSDictionary *dict = [propertyList objectForKey: pOKAllClassesKey];
	NSEnumerator *e = [[dict allKeys] objectEnumerator]; 
	NSString *key = nil;
	while ((key = [e nextObject]))
	{
		Class cls = NSClassFromString(key);
		[cls addPropertiesAndTypes: [dict objectForKey: key]];
	}

	/* Generate all objects */
	NSMutableDictionary *allObjects = [[NSMutableDictionary alloc] init];
	dict = [propertyList objectForKey: pOKAllObjectsKey];
	e = [[dict allKeys] objectEnumerator];
	while ((key = [e nextObject]))
	{
		NSDictionary *objectPL = [dict objectForKey: key];
		Class cls = NSClassFromString([objectPL objectForKey: pOKClassKey]);

		OKObject *object = nil;
		/* We check OKGroup first because OKGroup is subclass of OKObject */
		if ([cls isSubclassOfClass: [OKGroup class]])
		{
			/* Let make sure OKMultiValue is properly set */
			NSMutableDictionary *values = [[objectPL objectForKey: pOKValuesKey] mutableCopy];
			NSEnumerator *ee = [[values allKeys] objectEnumerator];
			NSString *property = nil;
			while ((property = [ee nextObject]));
			{
				if ([cls typeOfProperty: property] & kOKMultiValueMask)
				{
					OKMultiValue *mv = [[OKMultiValue alloc] initWithPropertyList: [values objectForKey: property]];
					[values setObject: mv forKey: property];
					DESTROY(mv);
				}
			}
			object = AUTORELEASE([[cls alloc] init]);
			[object->_properties addEntriesFromDictionary: values];
			DESTROY(values); // mutable copied above
		}
		else if ([cls isSubclassOfClass: [OKObject class]])
		{
			/* We need to put verion back here because OKObject need that */
			NSMutableDictionary *d = [objectPL mutableCopy];
//			[d setObject: pOKVersion1Value forKey: pOKVersionKey];
			object = [OKObject objectWithPropertyList: d];
			DESTROY(d);
		}
		else
		{
			NSLog(@"Error: unknown class %@", [objectPL objectForKey: pOKClassKey]);
		}

		[allObjects setObject: object forKey: key];
	}
	/* Include ourself */
	[allObjects setObject: self forKey: [self uniqueID]];

	/* Let's rebuild the group relationship */
	dict = [propertyList objectForKey: pOKAllGroupsKey];
	e = [[dict allKeys] objectEnumerator];
	NSString *uid = nil;
	while ((uid = [e nextObject]))
	{
		NSArray *members = [dict objectForKey: uid];
		OKGroup *group = [allObjects objectForKey: uid];
		if ((members == nil) || (group == nil))
		{
			NSLog(@"Internal Error: no object for uid %@", uid);
		}
		int i, count = [members count];
		for (i = 0; i < count; i++)
		{
			NSString *mid = [members objectAtIndex: i];
			OKObject *object = [allObjects objectForKey: mid];
			/* We check OKGroup first because OKGroup is subclass of OKObject */
			if ([object isKindOfClass: [OKGroup class]])
			{
				[group addSubgroup: (OKGroup *)object];
			}
			else if ([object isKindOfClass: [OKObject class]])
			{
				[group addObject: object];
			}
			else
			{
				NSLog(@"Error: unknown object %@", object);
			}
		}
	}

	DESTROY(allObjects);
	DESTROY(x);
}

/* End of Private */
- (id) initWithPropertyList: (id) propertyList
{
	self = [super initWithPropertyList: propertyList];

	NSString *v = [propertyList objectForKey: pOKVersionKey];
	if ([v isEqualToString: pOKVersion1Value])
	{
		[self _readGroupVersion1: propertyList];
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
	NSMutableDictionary *pl = nil;
	ASSIGN(pl, [super propertyList]); // pl got retained here

	CREATE_AUTORELEASE_POOL(x);
	/* We remove our parent and childrend */
	[[pl objectForKey: pOKValuesKey] removeObjectForKey: kOKParentsProperty];
	[[pl objectForKey: pOKValuesKey] removeObjectForKey: kOKGroupChildrenProperty];
	[[pl objectForKey: pOKValuesKey] removeObjectForKey: kOKGroupSubgroupsProperty];

	NSMutableDictionary *allObjects = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *classes = [[NSMutableDictionary alloc] init];
	OKObject *o = nil;
	OKGroup *g = nil;

	/* We first store everything flat */
	NSEnumerator *e = [[self allObjects] objectEnumerator];
	while ((o = [e nextObject]))
	{
		NSMutableDictionary *dict = [o propertyList];
		NSString *cls = [dict objectForKey: pOKClassKey];;
		if ([classes objectForKey: cls] == nil)
		{
			/* We cache this class */
			[classes setObject: [dict objectForKey: pOKPropertiesKey]
			            forKey: cls];
		}
		[dict removeObjectForKey: pOKPropertiesKey];
		[allObjects setObject: dict forKey: [o uniqueID]];
	}
	e = [[self allGroups] objectEnumerator];
	while ((g = [e nextObject]))
	{
		NSMutableDictionary *dict1 = [[NSMutableDictionary alloc] init];
		NSMutableDictionary *dict2 = nil;

		NSString *cls = NSStringFromClass([g class]);
		if ([classes objectForKey: cls] == nil)
		{
			/* We cache this class */
			[classes setObject: [[g class] propertiesAndTypes]
			            forKey: cls];
		}

		[dict1 setObject: cls forKey: pOKClassKey];

		dict2 = AUTORELEASE([g->_properties mutableCopy]);

		/* We remove parents and children property */
		[dict2 removeObjectForKey: kOKParentsProperty];
		[dict2 removeObjectForKey: kOKGroupChildrenProperty];
		[dict2 removeObjectForKey: kOKGroupSubgroupsProperty];

		/* If we have OKMultiValue, save its property list */
		NSEnumerator *e = [[dict2 allKeys] objectEnumerator];
		NSString *key = nil;
		while ((key = [e nextObject]))
		{
			id value = [dict2 objectForKey: key];
			if ([value isKindOfClass: [OKMultiValue class]])
			{
				[dict2 setObject: [(OKMultiValue *)value propertyList]
				          forKey: key];
			}
        }
		[dict1 setObject: dict2 forKey: pOKValuesKey];
		[allObjects setObject: dict1 forKey: [g uniqueID]];
		DESTROY(dict1);
	}
	[pl setObject: allObjects forKey: pOKAllObjectsKey];
	[pl setObject: classes forKey: pOKAllClassesKey];
	DESTROY(allObjects);
	DESTROY(classes);

	/* We store group relationship */
	NSMutableDictionary *groups = [[NSMutableDictionary alloc] init];
	NSMutableArray *array = [[self allGroups] mutableCopy];
	[array addObject: self];
	e = [array objectEnumerator];
	while ((g = [e nextObject]))
	{
		NSMutableArray *members = [[NSMutableArray alloc] init];
		NSMutableArray *uids = [[NSMutableArray alloc] init];
		[members addObjectsFromArray: [g objects]];
		[members addObjectsFromArray: [g subgroups]];
		int i, count = [members count];
		for (i = 0; i < count; i++)
		{
			[uids addObject: [[members objectAtIndex: i] uniqueID]];
		}
		[groups setObject: uids forKey: [g uniqueID]];
		DESTROY(members);
		DESTROY(uids);
	}
	[pl setObject: groups forKey: pOKAllGroupsKey];
	DESTROY(groups);
	DESTROY(array); // mutable copoied above
	[pl setObject: pOKVersion1Value forKey: pOKVersionKey];

	DESTROY(x);
	return AUTORELEASE(pl); // pl got auto-released here
}

- (BOOL) addObject: (OKObject *) object
{
	NSMutableArray *a = [self valueForProperty: kOKGroupChildrenProperty];
	if ([a containsObject: object] == NO)
	{
		[self _addAsParent: object];
		[a addObject: object];
		[_nc postNotificationName: kOKGroupAddObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: object forKey: kOKGroupChild]];
		return YES;
	}
	return NO;
}

- (BOOL) removeObject: (OKObject *) object
{
	NSMutableArray *a = [self valueForProperty: kOKGroupChildrenProperty];
	if ([a containsObject: object] == YES)
	{
		[self _removeAsParent: object];
		[a removeObject: object];
		[_nc postNotificationName: kOKGroupRemoveObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: object forKey: kOKGroupChild]];
		return YES;
	}
	return NO;
}

- (NSArray *) objects
{
	return [self valueForProperty: kOKGroupChildrenProperty];
}

- (BOOL) addSubgroup: (OKGroup *) group
{
	NSMutableArray *a = [self valueForProperty: kOKGroupSubgroupsProperty];
	if ([a containsObject: group] == NO)
	{
		[self _addAsParent: group];
		[a addObject: group];
		[_nc postNotificationName: kOKGroupAddObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: group forKey: kOKGroupChild]];
		return YES;
	}
	return NO;
}

- (BOOL) removeSubgroup: (OKGroup *) group
{
	NSMutableArray *a = [self valueForProperty: kOKGroupSubgroupsProperty];
	if ([a containsObject: group] == YES)
	{
		[self _removeAsParent: group];
		[a removeObject: group];
		[_nc postNotificationName: kOKGroupRemoveObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: group forKey: kOKGroupChild]];
		return YES;
	}
	return NO;
}

- (NSArray *) subgroups
{
	return [self valueForProperty: kOKGroupSubgroupsProperty];
}

- (NSArray *) objectsMatchingPredicate: (NSPredicate *) predicate
{
	NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
	NSArray *array = [self allObjects];
	int i, count = [array count];
	for (i = 0; i < count; i++)
	{
		OKObject *object = [array objectAtIndex: i];
		if ([object matchesPredicate: predicate])
			[set addObject: object];
	}
	return [set allObjects];
}

- (NSArray *) allObjects
{
	NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
	[set addObjectsFromArray: [self objects]];
	NSArray *array = [self subgroups];
	int i, count = [array count];
	for (i = 0; i < count; i++)
	{
		OKGroup *group = [array objectAtIndex: i];
		/* Try to prevent recursive */
		if ([group isEqual: self])
			continue;
		[set addObjectsFromArray: [group allObjects]];
	}
	return [set allObjects];
}

- (NSArray *) allGroups
{
	NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
	[set addObjectsFromArray: [self subgroups]];
	NSArray *array = [self subgroups];
	int i, count = [array count];
	for (i = 0; i < count; i++)
	{
		OKGroup *group = [array objectAtIndex: i];
		/* Try to prevent recursive */
		if ([group isEqual: self])
			continue;
		[set addObjectsFromArray: [group allGroups]];
	}
	return [set allObjects];
}

/* NSObject */
+ (void) initialize
{
	/* We need to repeat what is in OKObject 
	   because GNU objc runtime will not call super for this method */
	NSDictionary *pt = [OKObject propertiesAndTypes];
	[OKGroup addPropertiesAndTypes: pt];
	pt = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt: kOKStringProperty], 
			kOKGroupNameProperty,
		[NSNumber numberWithInt: kOKArrayProperty], 
			kOKGroupChildrenProperty,
		[NSNumber numberWithInt: kOKArrayProperty], 
			kOKGroupSubgroupsProperty,
		nil];
	[OKGroup addPropertiesAndTypes: pt];
	DESTROY(pt);
}

- (id) init
{
	self = [super init];
	/* Initialize children and parents property */
	[self setValue: AUTORELEASE([[NSMutableArray alloc] init])
	      forProperty: kOKGroupChildrenProperty];
	[self setValue: AUTORELEASE([[NSMutableArray alloc] init])
	      forProperty: kOKGroupSubgroupsProperty];
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

@end

