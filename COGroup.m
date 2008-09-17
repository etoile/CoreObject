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
- (void) mergeArray: (NSMutableArray *)existingChildren 
          intoArray: (NSMutableArray *)oldChildren
             policy: (COChildrenMergePolicy)aPolicy;
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

/* Data Model Declaration */

/** See +[COObject initialize] */
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

/* Property List Import/Export */

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
		ETLog(@"Unknown version %@", v);
		[self dealloc]; // FIXME: Why is this not -release?
		return nil;
	}

	return self;
}

/** Returns a property list representation of the core object graph connected 
    to the receiver.
    Depending on the cycles that exists in the object graph, the whole core 
    object graph can be exported in the returned property list. The serialized
    objects are all those returned by -allObjects. */
- (NSMutableDictionary *) propertyList
{
	return [self _outputGroupVersion1];
}

/* Common Methods */

/** <init /> */
- (id) init
{
	self = [super init];
	/* Initialize children and parents property */
	[self disablePersistency];
	[self setValue: [NSMutableArray array]
	      forProperty: kCOGroupChildrenProperty];
	[self setValue: [NSMutableArray array]
	      forProperty: kCOGroupSubgroupsProperty];
	[self enablePersistency];
	return self;
}

/** Returns YES by default.
    See also COGroup protocol and NSObject+Model in EtoileFoundation. */
- (BOOL) isGroup
{
	return YES;
}

/** Returns NO to indicate COGroup instances shouldn't be treated as opaque 
    object by default.
    -isOpaque explained in details in COGroup protocol.*/
- (BOOL) isOpaque
{
	return NO;
}

/* Managed Object Edition */

- (void) _addAsParent: (COObject *) object
{
	NSMutableArray *a = [object valueForProperty: kCOParentsProperty];
	if (a == nil)
	{
		[object setValue: [NSMutableArray array] forProperty: kCOParentsProperty];
	}
	[a addObject: self];
}

- (void) _removeAsParent: (COObject *) object
{
	NSMutableArray *a = [object valueForProperty: kCOParentsProperty];
	if (a != nil)
	{
		[a removeObject: self];
	}
}

/** Adds an object to the receiver children.
    anObject can be any objects that conform to COObject protocol, groups 
    included. Groups must conform to COGroup that itself conforms to COObject.
    Returns YES if the object was added, NO otherwise. anObject will be rejected 
    if it doesn't conform to COObject protocol, or is already a member of the 
    receiver.
    Subclasses can introduce additional constraints to control whether anObject 
    should be accepted or rejected. When writing a subclass, you must call 
    the superclass method in your implementation.  */
- (BOOL) addMember: (id)object
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

/** Removes an object from the receiver children.
    anObject can be any objects that conform to COObject protocol, groups 
    included. Groups must conform to COGroup that itself conforms to COObject.
    Returns YES if the object was removed, NO otherwise. anObject will be 
    rejected if it doesn't conform to COObject protocol, or isn't a member of 
    the receiver. 
    Subclasses can introduce additional constraints to control whether anObject 
    should be accepted or rejected. When writing a subclass, you must call 
    the superclass method in your implementation. */
- (BOOL) removeMember: (id)object
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

/** Returns the objects that belongs to the receiver.
    Groups are included in the returned array. */
- (NSArray *) members
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

- (NSArray *) allObjects
{
	NSMutableSet *set = [NSMutableSet set];
	[set addObjectsFromArray: [self members]];
	NSArray *array = [self groups];
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
	NSMutableSet *set = [NSMutableSet set];
	[set addObjectsFromArray: [self groups]];
	NSArray *array = [self groups];
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

/* Persistency */

+ (NSArray *) managedMethodNames
{
	NSArray *methodNames = A(NSStringFromSelector(@selector(addMember:)),
	                         NSStringFromSelector(@selector(removeMember:)),
	                         NSStringFromSelector(@selector(addGroup:)),
	                         NSStringFromSelector(@selector(removeGroup:)));

	return [methodNames arrayByAddingObjectsFromArray: [super managedMethodNames]];
}

/* Object Graph Query */

- (NSArray *) objectsMatchingPredicate: (NSPredicate *) predicate
{
	NSMutableSet *set = [NSMutableSet set];
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

/* Collection Protocol */

/** Returns NO by default.
    See ETCollection protocol in EtoileFoundation.
    You must override this method and -insertObject:atIndex:, if you write a 
    subclass whose children are ordered.
    You can override this method in your subclass, returning YES should be 
    enough since COGroup are implictly ordered. Both kCOGroupChildrenProperty 
    and kCOGroupSubgroupsProperty are mutable arrays. 
    See -mergeObjectsWithObjectsOfGroup:policy for merging related issues. */
- (BOOL) isOrdered
{
	return NO;
}

/** See ETCollection protocol in EtoileFoundation. */
- (BOOL) isEmpty
{
	return ([[self members] count] == 0);
}

/** See ETCollection protocol in EtoileFoundation. */
- (id) content
{
	return [self members];
}

/** See ETCollection protocol in EtoileFoundation. */
- (NSArray *) contentArray
{
	return [self content];
}

/** See ETCollectionMutation protocol in EtoileFoundation.
    You must override this method and -isOrdered, if you write a subclass whose 
    children are ordered. */
- (void) insertObject: (id)object atIndex: (unsigned int)index
{
	[self addMember: object];
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

	if ([[self members] containsObject: anObject] == NO)
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

	// NOTE: addMember: and -removeMember: won't work here, because 
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

/** Merges all the children of aGroup into the receiver children. The chilren 
    are the arrays returned by -objects on both the receiver and aGroup.
    The merge is done by applying the specified merge policy.
    This merge policy can be set on the object context, that call backs this 
    method when merging is necessary.
    NOTE: union and intersection don't try to maintain the order, so you 
    shouldn't expect the objects to be properly ordered after reverting a group.
    This doesn't matter for a COGroup which returns NO to -isOrdered, but if 
    your own subclass overrides it to return YES, be careful. You can
    eventually override this method to fix the order.  */
- (void) mergeObjectsWithObjectsOfGroup: (COGroup *)aGroup 
                                 policy: (COChildrenMergePolicy)aPolicy
{
	[self mergeArray: [aGroup valueForProperty: kCOGroupChildrenProperty]
	       intoArray: [self valueForProperty: kCOGroupChildrenProperty]
	          policy: aPolicy];
	[self mergeArray: [aGroup valueForProperty: kCOGroupSubgroupsProperty]
	       intoArray: [self valueForProperty: kCOGroupSubgroupsProperty]
	          policy: aPolicy];
}

/* Merges the first array elements into the second array by appliying the 
   specified merge policy: 
   - old (ignore the first array)
   - existing (add the elements of the second array into the first array)
   - union
   - intersection. 
   FIXME: union and intersection don't try to maintain the order. Not sure this 
   will ever prove to be an issue. Eventually we could design our own 
   NSSortedSet class as an NSArray replacement, but only for merging purpose.
   Relying on it in other cases would make property list export/import more 
   complex. */
- (void) mergeArray: (NSMutableArray *)existingChildren 
          intoArray: (NSMutableArray *)oldChildren
             policy: (COChildrenMergePolicy)aPolicy
{
	switch (aPolicy)
	{
		case COOldChildrenMergePolicy:
			break;
		case COExistingChildrenMergePolicy:
			[oldChildren setArray: existingChildren];
			break;
		case COChildrenUnionMergePolicy:
		{
			NSMutableSet *oldChildrenSet = [NSMutableSet setWithArray: oldChildren];

			[oldChildrenSet unionSet: [NSSet setWithArray: existingChildren]];
			[oldChildren setArray: [oldChildrenSet allObjects]];
			break;
		}
		case COChildrenIntersectionMergePolicy:
		{
			NSMutableSet *oldChildrenSet = [NSMutableSet setWithArray: oldChildren];

			[oldChildrenSet intersectSet: [NSSet setWithArray: existingChildren]];
			[oldChildren setArray: [oldChildrenSet allObjects]];
			break;
		}
	}
}

/* Faulting */

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

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */

- (BOOL) addObject: (id) object { return [self addMember: object]; }
- (BOOL) removeObject: (id) object { return [self removeMember: object]; }
- (NSArray *) objects { return [self members]; }

@end
