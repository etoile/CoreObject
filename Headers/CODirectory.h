/*
   Copyright (C) 2008 Quentin Mathe <qmathe@club-internet.fr>

   This application is free software; you can redistribute it and/or 
   modify it under the terms of the MIT license. See COPYING.

*/

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import "COCoreObjectProtocol.h"
#import "COFile.h"


@interface CODirectory : COFile <COGroup>
{

}

+ (BOOL) isGroupAtURL: (NSURL *)anURL;

+ (CODirectory *) trashDirectory;

+ (id) delegate;
+ (void) setDelegate: (id)delegate;
// TODO: Implement
//+ (BOOL) shouldCreateAddedObjectIfNeeded;
//+ (void) setShouldCreateAddedObjectIfNeeded: (BOOL)flag;

- (BOOL) isValidObject: (id)object;
- (BOOL) containsObject: (id)object;
- (BOOL) addMember: (id)object;
- (BOOL) removeMember: (id)object;
- (BOOL) deleteObject: (id)object;
- (NSArray *) members;

- (BOOL) addSymbolicLink: (id)object;
- (BOOL) addHardLink: (id)object;

- (BOOL) create;

/* Collection protocol (except -removeObject: declared previously) */

- (BOOL) isOrdered;
- (BOOL) isEmpty;
- (id) content;
- (NSArray *) contentArray;
- (void) insertObject: (id)object atIndex: (unsigned int)index;
- (BOOL) removeObject: (id)object;

/* Deprecated (DO NOT USE, WILL BE REMOVED LATER) */

- (BOOL) addObject: (id)object;
- (NSArray *) objects;

@end

