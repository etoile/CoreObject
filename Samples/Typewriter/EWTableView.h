/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

@class EWTableView;

@protocol EWTableViewDelegate
- (NSMenu *) tableView: (EWTableView *)aTableView menuForEvent: (NSEvent *)anEvent defaultMenu: (NSMenu *)aMenu;
@end

@interface EWTableView : NSTableView
@end
