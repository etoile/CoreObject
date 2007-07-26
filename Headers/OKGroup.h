/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/
#import "OKObject.h"

extern NSString *kOKGroupNameProperty;
extern NSString *kOKGroupChildrenProperty;
extern NSString *kOKGroupSubgroupsProperty;

/* object is self. 
   use userInfo with kOKGroupChild to know which one is add or removed */
extern NSString *kOKGroupAddObjectNotification;
extern NSString *kOKGroupRemoveObjectNotification;
extern NSString *kOKGroupAddSubgroupNotification;
extern NSString *kOKGroupRemoveSubgroupNotification;
extern NSString *kOKGroupChild;

@interface OKGroup: OKObject
- (BOOL) addObject: (OKObject *) object;
- (BOOL) removeObject: (OKObject *) object;
- (NSArray *) objects;

- (BOOL) addSubgroup: (OKGroup *) group;
- (BOOL) removeSubgroup: (OKGroup *) group;
- (NSArray *) subgroups;

- (NSArray *) allObjects; /* Not group */
- (NSArray *) allGroups;

- (NSArray *) objectsMatchingPredicate: (NSPredicate *) predicate;

@end

