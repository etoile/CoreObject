/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.f>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObject.h"
#import "COGroup.h"
#import "COMultiValue.h"

/* Property list format reading and ouput for CoreObject adaptive model. 
   Only one format version exists for now. 
   Future _readObjectVersionX: and _ouputObjectVersionX methods should be added 
   to COObject and COGroup in this file. */

NSString *pCOClassKey = @"Class";
NSString *pCOPropertiesKey = @"Properties";
NSString *pCOValuesKey = @"Values";
NSString *pCOVersionKey = @"Version";
NSString *pCOVersion1Value = @"COVersion1";

@implementation COObject (COPropertyListFormat)

/* Property list format reading.
   Writing for the last format version is presently handled directly in 
   -propertyList within COObject.m. */
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

- (NSMutableDictionary *) _outputObjectVersion1
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

@end

/* COGroup specific keys for plist format */
NSString *pCOAllObjectsKey = @"AllObjects";
NSString *pCOAllClassesKey = @"AllClasses";
NSString *pCOAllGroupsKey = @"AllGroups";

@implementation COGroup (COPropertyListFormat)

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
			// FIXME: We shouldn't need the following double cases now that -addMember: handles both objects and groups.
			if ([object isKindOfClass: [COGroup class]])
			{
				[group addGroup: (COGroup *)object];
			}
			else if ([object isKindOfClass: [COObject class]])
			{
				[group addMember: object];
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

- (NSMutableDictionary *) _outputGroupVersion1
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
		[members addObjectsFromArray: [g members]];
		 // FIXME: Shouldn't be needed anymore now that [g members] returns both objects and groups
		[members addObjectsFromArray: [g groups]];
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

@end
