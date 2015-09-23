/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import "PreferencesController.h"

@class EWTypewriterWindowController;

@interface EWAppDelegate : NSObject <NSApplicationDelegate>
{
	COEditingContext *ctx;
	COPersistentRoot *library;
	
	EWTypewriterWindowController *windowController;
	
	NSMutableArray *utilityWindowControllers;
	PreferencesController *prefsController;
}

@property (nonatomic, readonly) COEditingContext *editingContext;
@property (nonatomic, readonly) COPersistentRoot *libraryPersistentRoot;

- (IBAction) orderFrontTypewriter: (id)sender;
- (IBAction) orderFrontPreferences: (id)sender;

- (void) addWindowController: (NSWindowController *)aController;
- (void) removeWindowController: (NSWindowController *)aController;

- (void) clearUndo;

@end
