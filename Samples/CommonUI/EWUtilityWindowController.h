/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>


/**
 * Abstract superclass for utility window controllers.
 *
 * Currently all it does is return the active document's undo manager
 */
@interface EWUtilityWindowController : NSWindowController

- (void) setInspectedWindowController: (NSWindowController *)aDoc;

@end
