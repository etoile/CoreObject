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
#import "NSObject+CoreObject.h"

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

@interface COGroup (Private)
- (void) _addAsParent: (COObject *) object;
- (void) _removeAsParent: (COObject *) object;
- (void) _replaceFaultObject: (id)aFault 
                     inArray: (NSMutableArray *)objects 
                  withObject: (id)resolvedObject;
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

/* Merging */

/** Returns whether the receiver contains a temporal instance of anObject.
    See -[COObject isTemporalInstance:]. */
- (BOOL) containsTemporalInstance: (id)anObject
{
	NSMutableArray *strictObjects = [self valueForProperty: kCOGroupChildrenProperty];
	NSMutableArray *subgroups = [self valueForProperty: kCOGroupSubgroupsProperty];

	// NOTE: If this is too slow, we can speed it up by caching 
	// -isTemporalInstance: IMP or even altering eqSel internal ivar of NSArray 
	// for the comparison selector and then just calls -containsObject: 
	// before restoring the comparison selector. The last option means using a 
	// category on NSArray.

	if ([anObject isGroup])
	{
		FOREACHI(subgroups, aChildGroup)
		{
			if ([anObject isTemporalInstance: aChildGroup])
				return YES;;
		}
	}
	else
	{
		FOREACHI(strictObjects, aChildObject)
		{
			if ([anObject isTemporalInstance: aChildObject])
				return YES;
		}
	}

	return NO;
}

/** No merging strategy is implemented by COObject.
    COGroup is the only subclass which handles merging of replacement objects. */
- (COMergeResult) replaceObject: (id)anObject 
                       byObject: (id)otherObject 
                isTemporalMerge: (BOOL)temporal 
                          error: (NSError **)error
{
	if (temporal && [otherObject isMemberOfClass: [anObject class]] == NO)
	{
		ETLog(@"WARNING: Merged object class %@ must be identical to replaced "
			"object class %@ for a temporal replacement", otherObject, anObject);
		return COMergeResultNone;
	}

	if ([[self objects] containsObject: anObject] == NO)
		return COMergeResultNone; // Nothing to merge in the receiver
	//if ([self containsTemporalInstance: otherObject])
	//	return COMergeResultNone; // Nothing to merge in the receiver

	/* Otherwise the merging really happens now */
	NSMutableArray *targetChildObjects = nil;
	BOOL isGroupReplacement = [otherObject isKindOfClass: [COGroup class]];

	if (isGroupReplacement)
	{
		targetChildObjects = [self valueForProperty: kCOGroupSubgroupsProperty];
	}
	else
	{
		targetChildObjects = [self valueForProperty: kCOGroupChildrenProperty];

	}

	// TODO: If we want to support this method for non-temporal replacement 
	// we need to synthetize a add and a remove invocation record here.
	//RECORD(anObject, otherObject, NULL)

	// NOTE: addObject: and -removeObject: won't work here, because 
	// IGNORE_CHANGES makes them return immediately when a revert is underway. 

	/* The following code implictly set valid references to parents for 
	   otherObject, by the mean of _addAsParent:. 
	   If otherObject isn't a temporal instance, it will continue to reference 
	   the same parents as before in addition to self. So it shouldn't expected 
	   that this method will make otherObject have the parent references of 
	   anObject. 
	   If it is a temporal instance, the valid parent references are recreated 
	   by having the object context calls this method on each registered group 
	   to remove andObject and insert otherObject. */
	int indexOfReplacedObject = [targetChildObjects indexOfObject: anObject];
	[self _removeAsParent: anObject];
	[targetChildObjects removeObject: anObject];
	[self _addAsParent: otherObject];
	[targetChildObjects insertObject: otherObject atIndex: indexOfReplacedObject];
	// TODO: Post a kGroupMergeObjectNotification.
	//	[_nc postNotificationName: kCOGroupMergeObjectNotification
	//	     object: self
	//	     userInfo: D(anObject, kCOGroupTargetChild, otherObject, kCOGroupMergedChild)];

	//END_RECORD

	return COMergeResultSucceeded;
}

/** Returns whether some childen of the receiver are fault markers and not 
    real objects. */
- (BOOL) hasFaults
{
	return _hasFaults;
}

/** Resolves all the existing faults in the children of the receiver, by 
    replacing them with the real objects they represent or by keeping them 
    as is if no real object can be resolved. 
    -objects automatically tries to resolve faults by calling this method.
    An fault may not be resolved if no valid UUID/URL pair exists in the 
    metadata server, or if the URL isn't unreachable and prevents the object to 
    be deserialized. Until unresolved faults exist, -hasFaults will return YES 
    and -objects will try to resolve them each time you call it. */
- (void) resolveFaults
{
	if ([self hasFaults] == NO)
		return;

	// NOTE: Don't call -objects here, because it calls -resolveFaults.
	NSMutableArray *childObjects = [self valueForProperty: kCOGroupChildrenProperty];
	NSMutableArray *subgroupObjects = [self valueForProperty: kCOGroupSubgroupsProperty];
	NSArray *objects = [childObjects arrayByAddingObjectsFromArray: subgroupObjects];
	id resolvedObject = nil;
	BOOL resolvedAllFaults = YES;

	FOREACHI(objects, anObject)
	{
		if ([anObject isFault])
		{
			resolvedObject = [[self objectContext] resolvedObjectForFault: anObject];

			if (resolvedObject == nil)
			{
				resolvedAllFaults = NO;
				ETLog(@"NOTE: No object available for UUID %@", anObject);
			}
		}

		// TODO: Probably replace by -isGroup...
		if ([anObject isKindOfClass: [COGroup class]])
		{
			[self _replaceFaultObject: anObject inArray: subgroupObjects withObject: resolvedObject];
		}
		else
		{
			[self _replaceFaultObject: anObject inArray: childObjects withObject: resolvedObject];
		}
	}

	if (resolvedAllFaults)
		_hasFaults = NO;
}

- (void) _replaceFaultObject: (id)aFault 
                     inArray: (NSMutableArray *)objects 
                  withObject: (id)resolvedObject
{
	if (resolvedObject != nil)
	{
		int faultIndex = [objects indexOfObject: aFault];
		[objects replaceObjectAtIndex: faultIndex withObject: resolvedObject];
	}
	else
	{
		[objects removeObject: aFault];
	}
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

