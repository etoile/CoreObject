/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  April 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

@interface EWDiffWindowController : NSWindowController
{
	IBOutlet NSTextView *textView;
	COPersistentRoot *inspectedPersistentRoot;
}

- (instancetype) initWithInspectedPersistentRoot: (COPersistentRoot *)aPersistentRoot;

@end
