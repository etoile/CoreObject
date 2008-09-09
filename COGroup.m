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

NSString *kCOGroupAddObjectNotification = @"kCOGroupAddObjectNotification";
NSString *kCOGroupRemoveObjectNotification = @"kCOGroupRemoveObjectNotification";
NSString *kCOGroupAddSubgroupNotification = @"kCOGroupAddSubgroupNotification";
NSString *kCOGroupRemoveSubgroupNotification = @"kCOGroupRemoveSubgroupNotification";
NSString *kCOGroupChild = @"kCOGroupChild";

@interface COGroup (COPropertyListFormat)
- (void) _readGroupVersion1: (NSDictionary *)propertyList;
- (NSMutableDictionary *) _outputGroupVersion1;
@end


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

+ (NSArray *) managedMethodNames
{
	NSArray *methodNames = A(NSStringFromSelector(@selector(addObject:)),
	                         NSStringFromSelector(@selector(removeObject:)),
	                         NSStringFromSelector(@selector(addGroup:)),
	                         NSStringFromSelector(@selector(removeGroup:)));

	return [methodNames arrayByAddingObjectsFromArray: [super managedMethodNames]];
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
	return [self _outputGroupVersion1];
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
	if ([object conformsToProtocol: @protocol(COGroup)])
		return [self addGroup: (id <COGroup>)object];
		
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
	if ([object conformsToProtocol: @protocol(COGroup)])
		return [self removeGroup: (id <COGroup>)object];

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
	return [[self valueForProperty: kCOGroupChildrenProperty] arrayByAddingObjectsFromArray:
	            [self valueForProperty: kCOGroupSubgroupsProperty]];
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
	[self disablePersistency];
	[self setValue: AUTORELEASE([[NSMutableArray alloc] init])
	      forProperty: kCOGroupChildrenProperty];
	[self setValue: AUTORELEASE([[NSMutableArray alloc] init])
	      forProperty: kCOGroupSubgroupsProperty];
	[self enablePersistency];
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

@end

