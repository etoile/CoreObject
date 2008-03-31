/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>
                 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import "COObject.h"
#import <EtoileFoundation/EtoileFoundation.h>

/* CoreObject Protocol (Relationships) */

@protocol COGroup <COObject, ETCollection>

/** Must return YES to indicate the receiver is a group. */
- (BOOL) isGroup;

/** Adds object to the receiver. 
	This method must call -addGroup: if the object passed in paremeter is a 
	COGroup instance. */
- (BOOL) addObject: (id <COObject>)object;
- (BOOL) removeObject: (id <COObject>)object;
/** Returns objects directly owned by the receiver, that includes every objects 
	and subgroups which are immediate children. */
- (NSArray *) objects;

/** Adds subgroup to the receiver.
	The class that implements this method must not call -addObject: directly.
	-addObject: and -addGroup should rather call a common private method like 
	_addObject: if they want to share their implementation. 
	WARNING: Documentation below needs to be refined once we have produced some 
	concrete use cases.
	In many implementation cases, this method involves no other work than 
	-addObject:. However it is useful when you want to introduce some special 
	handling or semantic for the ownership of subgroups. For example, you could 
	tailor it for special indexing, storing and caching of relationships or even 
	generate new groups for the insertion of the given subgroup. This last 
	option represents the possibility to compute or generate lazily new 
	relationships based on existing relationships between objects and other 
	conditions. */
- (BOOL) addGroup: (id <COGroup>)subgroup;
/** Removes subgroup from the receiver. */
- (BOOL) removeGroup: (id <COGroup>)subgroup;
/** Returns subgroups directly owned by the receiver, that includes every groups 
	which are immediate children. */
- (NSArray *) groups;

/** Returns all objects belonging to this group, that includes immediate 
	children returned by -objects and other descendent children. */
- (NSArray *) allObjects; /* Not group */
- (NSArray *) allGroups;

/** Returns YES when the receiver should be handled and displayed as a COObject 
	instance rather than a COGroup instance. For example, a source file may
	appear as an opaque element in a file manager but as a group of classes, 
	functions, methods and variables in an IDE.
	Each application is in charge of interpreting or ignoring -isOpaque value 
	as it wants within the code that implements the browsing of core object 
	graphs. */
- (BOOL) isOpaque;
@end

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

@interface COGroup: COObject
- (BOOL) addObject: (COObject *) object;
- (BOOL) removeObject: (COObject *) object;
- (NSArray *) objects;

- (BOOL) addSubgroup: (COGroup *) group;
- (BOOL) removeSubgroup: (COGroup *) group;
- (NSArray *) subgroups;

- (NSArray *) allObjects; /* Not group */
- (NSArray *) allGroups;

- (NSArray *) objectsMatchingPredicate: (NSPredicate *) predicate;

@end

