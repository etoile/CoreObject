/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@class EWTypewriterWindowController;

@interface EWAppDelegate : NSObject
{
	COEditingContext *ctx;
	COPersistentRoot *library;
	
	EWTypewriterWindowController *windowController;
	
	NSMutableArray *utilityWindowControllers;
}

@property (nonatomic, readonly) COEditingContext *editingContext;
@property (nonatomic, readonly) COPersistentRoot *libraryPersistentRoot;

- (IBAction) orderFrontTypewriter: (id)sender;

- (void) addWindowController: (NSWindowController *)aController;
- (void) removeWindowController: (NSWindowController *)aController;

@end
