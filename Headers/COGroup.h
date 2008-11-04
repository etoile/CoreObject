/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>
                 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObject.h"
#import "COObjectContext.h"
#import "COCoreObjectProtocol.h"
#import <EtoileFoundation/EtoileFoundation.h>

extern NSString *kCOGroupNameProperty;
extern NSString *kCOGroupChildrenProperty;
extern NSString *kCOGroupSubgroupsProperty;

/* object is self. 
   use userInfo with kCOGroupChild to know which one is add or removed */
extern NSString *kCOGroupAddObjectNotification;
extern NSString *kCOGroupRemoveObjectNotification;
extern NSString *kCOGroupAddSubgroupNotification;
extern NSString *kCOGroupRemoveSubgroupNotification;
extern NSString *kCOGroupChild;

@interface COGroup: COObject <COGroup>
{
	BOOL _hasFaults; /** Transient flag set to YES on deserialization (see -finishedDeserializing) */
}

+ (BOOL) isGroupAtURL: (NSURL *)anURL;
+ (id) objectWithURL: (NSURL *)url;

/* Data Model Declaration */

+ (void) initialize;

/* Common Methods */

- (id) init;
- (BOOL) isGroup;
- (BOOL) isOpaque;
- (NSString *) displayName;

/* Managed Object Edition */

- (BOOL) addMember: (id)object;
- (BOOL) removeMember: (id)object;
- (NSArray *) members;

- (BOOL) addGroup: (id <COGroup>)aGroup;
- (BOOL) removeGroup: (id <COGroup>)aGroup;
- (NSArray *) groups;

- (NSArray *) allObjects;
- (NSArray *) allGroups;

/* Persistency */

+ (NSArray *) managedMethodNames;

/* Object Graph Query */

- (NSArray *) objectsMatchingPredicate: (NSPredicate *)aPredicate;

/* Collection Protocol */

- (BOOL) isOrdered;
- (BOOL) isEmpty;
- (id) content;
- (NSArray *) contentArray;
- (NSArray *) objects;
- (BOOL) addObject: (id) object;
- (BOOL) removeObject: (id) object;
- (void) insertObject: (id)object atIndex: (unsigned int)index;

/* Merging */

- (BOOL) containsTemporalInstance: (id)anObject;
- (COMergeResult) replaceObject: (id)anObject 
                       byObject: (id)otherObject 
                isTemporalMerge: (BOOL)temporal 
                          error: (NSError **)error;
- (void) mergeObjectsWithObjectsOfGroup: (COGroup *)aGroup policy: (COChildrenMergePolicy)aPolicy;

/* Faulting */

- (BOOL) hasFaults;
- (void) setHasFaults: (BOOL)flag;
- (void) resolveFaults;
- (BOOL) tryResolveFault: (ETUUID *)aFault;

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */

- (BOOL) addObject: (id) object;
- (BOOL) removeObject: (id) object;
- (NSArray *) objects;

@end

