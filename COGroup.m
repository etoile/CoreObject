/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COGroup.h"
#import "COMultiValue.h"
#import "GNUstep.h"
#import "COObjectContext.h"
#import "COUtility.h"


NSString *kCOGroupNameProperty = @"kCOGroupNameProperty";
NSString *kCOGroupChildrenProperty = @"kCOGroupChildrenProperty";
NSString *kCOGroupSubgroupsProperty = @"kCOGroupSubgroupsProperty";

NSString *pCOAllObjectsKey = @"AllObjects";
NSString *pCOAllClassesKey = @"AllClasses";
NSString *pCOAllGroupsKey = @"AllGroups";

NSString *kCOGroupAddObjectNotification = @"kCOGroupAddObjectNotification";
NSString *kCOGroupRemoveObjectNotification = @"kCOGroupRemoveObjectNotification";
NSString *kCOGroupAddSubgroupNotification = @"kCOGroupAddSubgroupNotification";
NSString *kCOGroupRemoveSubgroupNotification = @"kCOGroupRemoveSubgroupNotification";
NSString *kCOGroupChild = @"kCOGroupChild";

@implementation COGroup

// TODO: Implement
+ (BOOL) isGroupAtURL: (NSURL *)anURL
{
	return NO;
}

// TODO: Implement
+ (id) objectWithURL: (NSURL *)url
{
	return nil;
}


/* Private */
- (void) _addAsParent: (COObject *) object
{
	NSMutableArray *a = [object valueForProperty: kCOParentsProperty];
	if (a == nil)
	{
		a = AUTORELEASE([[NSMutableArray alloc] init]);
		[object setValue: a forProperty: kCOParentsProperty];
	}
	[a addObject: self];
}

- (void) _removeAsParent: (COObject *) object
{
	NSMutableArray *a = [object valueForProperty: kCOParentsProperty];
	if (a)
	{
		[a removeObject: self];
	}
}

- (void) _readGroupVersion1: (NSDictionary *) propertyList
{
	CREATE_AUTORELEASE_POOL(x);

	/* Generate all classes */
	NSDictionary *dict = [propertyList objectForKey: pCOAllClassesKey];
	NSEnumerator *e = [[dict allKeys] objectEnumerator]; 
	NSString *key = nil;
	while ((key = [e nextObject]))
	{
		Class cls = NSClassFromString(key);
		[cls addPropertiesAndTypes: [dict objectForKey: key]];
	}

	/* Generate all objects */
	NSMutableDictionary *allObjects = [[NSMutableDictionary alloc] init];
	dict = [propertyList objectForKey: pCOAllObjectsKey];
	e = [[dict allKeys] objectEnumerator];
	while ((key = [e nextObject]))
	{
		NSDictionary *objectPL = [dict objectForKey: key];
		Class cls = NSClassFromString([objectPL objectForKey: pCOClassKey]);

		COObject *object = nil;
		/* We check COGroup first because COGroup is subclass of COObject */
		if ([cls isSubclassOfClass: [COGroup class]])
		{
			/* Let make sure COMultiValue is properly set */
			NSMutableDictionary *values = [[objectPL objectForKey: pCOValuesKey] mutableCopy];
			NSEnumerator *ee = [[values allKeys] objectEnumerator];
			NSString *property = nil;
			while ((property = [ee nextObject]));
			{
				if ([cls typeOfProperty: property] & kCOMultiValueMask)
				{
					COMultiValue *mv = [[COMultiValue alloc] initWithPropertyList: [values objectForKey: property]];
					[values setObject: mv forKey: property];
					DESTROY(mv);
				}
			}
			object = AUTORELEASE([[cls alloc] init]);
			[object->_properties addEntriesFromDictionary: values];
			DESTROY(values); // mutable copied above
		}
		else if ([cls isSubclassOfClass: [COObject class]])
		{
			/* We need to put verion back here because COObject need that */
			NSMutableDictionary *d = [objectPL mutableCopy];
//			[d setObject: pCOVersion1Value forKey: pCOVersionKey];
			object = [COObject objectWithPropertyList: d];
			DESTROY(d);
		}
		else
		{
			NSLog(@"Error: unknown class %@", [objectPL objectForKey: pCOClassKey]);
		}

		[allObjects setObject: object forKey: key];
	}
	/* Include ourself */
	[allObjects setObject: self forKey: [self uniqueID]];

	/* Let's rebuild the group relationship */
	dict = [propertyList objectForKey: pCOAllGroupsKey];
	e = [[dict allKeys] objectEnumerator];
	NSString *uid = nil;
	while ((uid = [e nextObject]))
	{
		NSArray *members = [dict objectForKey: uid];
		COGroup *group = [allObjects objectForKey: uid];
		if ((members == nil) || (group == nil))
		{
			NSLog(@"Internal Error: no object for uid %@", uid);
		}
		int i, count = [members count];
		for (i = 0; i < count; i++)
		{
			NSString *mid = [members objectAtIndex: i];
			COObject *object = [allObjects objectForKey: mid];
			/* We check COGroup first because COGroup is subclass of COObject */
			if ([object isKindOfClass: [COGroup class]])
			{
				[group addSubgroup: (COGroup *)object];
			}
			else if ([object isKindOfClass: [COObject class]])
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

	NSString *v = [propertyList objectForKey: pCOVersionKey];
	if ([v isEqualToString: pCOVersion1Value])
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
	[[pl objectForKey: pCOValuesKey] removeObjectForKey: kCOParentsProperty];
	[[pl objectForKey: pCOValuesKey] removeObjectForKey: kCOGroupChildrenProperty];
	[[pl objectForKey: pCOValuesKey] removeObjectForKey: kCOGroupSubgroupsProperty];

	NSMutableDictionary *allObjects = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *classes = [[NSMutableDictionary alloc] init];
	COObject *o = nil;
	COGroup *g = nil;

	/* We first store everything flat */
	NSEnumerator *e = [[self allObjects] objectEnumerator];
	while ((o = [e nextObject]))
	{
		NSMutableDictionary *dict = [o propertyList];
		NSString *cls = [dict objectForKey: pCOClassKey];;
		if ([classes objectForKey: cls] == nil)
		{
			/* We cache this class */
			[classes setObject: [dict objectForKey: pCOPropertiesKey]
			            forKey: cls];
		}
		[dict removeObjectForKey: pCOPropertiesKey];
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

		[dict1 setObject: cls forKey: pCOClassKey];

		dict2 = AUTORELEASE([g->_properties mutableCopy]);

		/* We remove parents and children property */
		[dict2 removeObjectForKey: kCOParentsProperty];
		[dict2 removeObjectForKey: kCOGroupChildrenProperty];
		[dict2 removeObjectForKey: kCOGroupSubgroupsProperty];

		/* If we have COMultiValue, save its property list */
		NSEnumerator *e = [[dict2 allKeys] objectEnumerator];
		NSString *key = nil;
		while ((key = [e nextObject]))
		{
			id value = [dict2 objectForKey: key];
			if ([value isKindOfClass: [COMultiValue class]])
			{
				[dict2 setObject: [(COMultiValue *)value propertyList]
				          forKey: key];
			}
        }
		[dict1 setObject: dict2 forKey: pCOValuesKey];
		[allObjects setObject: dict1 forKey: [g uniqueID]];
		DESTROY(dict1);
	}
	[pl setObject: allObjects forKey: pCOAllObjectsKey];
	[pl setObject: classes forKey: pCOAllClassesKey];
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
			[uids addObject: [(id <COObject>)[members objectAtIndex: i] uniqueID]];
		}
		[groups setObject: uids forKey: [g uniqueID]];
		DESTROY(members);
		DESTROY(uids);
	}
	[pl setObject: groups forKey: pCOAllGroupsKey];
	DESTROY(groups);
	DESTROY(array); // mutable copoied above
	[pl setObject: pCOVersion1Value forKey: pCOVersionKey];

	DESTROY(x);
	return AUTORELEASE(pl); // pl got auto-released here
}

- (BOOL) isGroup
{
	return YES;
}

- (BOOL) isOpaque
{
	return NO;
}

- (BOOL) addObject: (COObject *) object
{
	NSMutableArray *a = [self valueForProperty: kCOGroupChildrenProperty];
	if ([a containsObject: object] == NO)
	{
		if (IGNORE_CHANGES || [self isReadOnly])
			return NO;
	
		RECORD(object)

		[self _addAsParent: object];
		[a addObject: object];
		[_nc postNotificationName: kCOGroupAddObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: object forKey: kCOGroupChild]];

		END_RECORD

		return YES;
	}
	return NO;
}

- (BOOL) removeObject: (COObject *) object
{
	NSMutableArray *a = [self valueForProperty: kCOGroupChildrenProperty];
	if ([a containsObject: object] == YES)
	{
		if (IGNORE_CHANGES || [self isReadOnly])
			return NO;
	
		RECORD(object)

		[self _removeAsParent: object];
		[a removeObject: object];
		[_nc postNotificationName: kCOGroupRemoveObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: object forKey: kCOGroupChild]];

		END_RECORD

		return YES;
	}
	return NO;
}

- (NSArray *) objects
{
	return [self valueForProperty: kCOGroupChildrenProperty];
}

- (BOOL) addGroup: (id <COGroup>)subgroup
{
	return [self addSubgroup: subgroup];
}

- (BOOL) removeGroup: (id <COGroup>)subgroup
{
	return [self removeSubgroup: subgroup];
}

- (NSArray *) groups
{
	return [self subgroups];
}

- (BOOL) addSubgroup: (COGroup *) group
{
	NSMutableArray *a = [self valueForProperty: kCOGroupSubgroupsProperty];
	if ([a containsObject: group] == NO)
	{
		if (IGNORE_CHANGES || [self isReadOnly])
			return NO;
	
		RECORD(group)

		[self _addAsParent: group];
		[a addObject: group];
		[_nc postNotificationName: kCOGroupAddObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: group forKey: kCOGroupChild]];

		END_RECORD

		return YES;
	}
	return NO;
}

- (BOOL) removeSubgroup: (COGroup *) group
{
	NSMutableArray *a = [self valueForProperty: kCOGroupSubgroupsProperty];
	if ([a containsObject: group] == YES)
	{
		if (IGNORE_CHANGES || [self isReadOnly])
			return NO;
	
		RECORD(group)

		[self _removeAsParent: group];
		[a removeObject: group];
		[_nc postNotificationName: kCOGroupRemoveObjectNotification
		     object: self
		     userInfo: [NSDictionary dictionaryWithObject: group forKey: kCOGroupChild]];

		END_RECORD

		return YES;
	}
	return NO;
}

- (NSArray *) subgroups
{
	return [self valueForProperty: kCOGroupSubgroupsProperty];
}

- (NSArray *) objectsMatchingPredicate: (NSPredicate *) predicate
{
	NSMutableSet *set = AUTORELEASE([[NSMutableSet alloc] init]);
	NSArray *array = [self allObjects];
	int i, count = [array count];
	for (i = 0; i < count; i++)
	{
		COObject *object = [array objectAtIndex: i];
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
		COGroup *group = [array objectAtIndex: i];
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
		COGroup *group = [array objectAtIndex: i];
		/* Try to prevent recursive */
		if ([group isEqual: self])
			continue;
		[set addObjectsFromArray: [group allGroups]];
	}
	return [set allObjects];
}

// NOTE: We may want to be ordered... we return arrays for methods like -objects
- (BOOL) isOrdered
{
	return NO;
}

- (BOOL) isEmpty
{
	return ([[self objects] count] == 0);
}

- (id) content
{
	return [self objects];
}

- (NSArray *) contentArray
{
	return [self content];
}

- (void) insertObject: (id)object atIndex: (unsigned int)index
{
	// FIXME: If we decide to return YES in -isOrdered, modify...
	[self addObject: object];
}

/* NSObject */
+ (void) initialize
{
	/* We need to register COObject properties and types by calling super 
	   because GNU objc runtime will not call +initialize on superclass as 
	   NeXT runtime does. */
	[super initialize];
	NSDictionary *pt = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt: kCOStringProperty], 
			kCOGroupNameProperty,
		[NSNumber numberWithInt: kCOArrayProperty], 
			kCOGroupChildrenProperty,
		[NSNumber numberWithInt: kCOArrayProperty], 
			kCOGroupSubgroupsProperty,
		nil];
	[self addPropertiesAndTypes: pt];
	DESTROY(pt);
}

- (id) init
{
	self = [super init];
	/* Initialize children and parents property */
	[self setValue: AUTORELEASE([[NSMutableArray alloc] init])
	      forProperty: kCOGroupChildrenProperty];
	[self setValue: AUTORELEASE([[NSMutableArray alloc] init])
	      forProperty: kCOGroupSubgroupsProperty];
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

@end

