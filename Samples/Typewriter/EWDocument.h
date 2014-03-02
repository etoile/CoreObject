/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

#import <CoreObject/CoreObject.h>

#import "EWUndoManager.h"

@interface EWDocument : NSDocument
{
	COEditingContext *ctx;
	COPersistentRoot *library;
}

@property (nonatomic, readonly) COEditingContext *editingContext;
@property (nonatomic, readonly) COPersistentRoot *libraryPersistentRoot;

- (instancetype) initWithStoreURL: (NSURL *)aURL;

@end
