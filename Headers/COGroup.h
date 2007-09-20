/*
   Copyright (C) 2007 Yen-Ju Chen <yjchenx gmail>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/
#import "COObject.h"

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

