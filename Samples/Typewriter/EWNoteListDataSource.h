/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class EWTypewriterWindowController;

@interface EWNoteListDataSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
	NSMutableSet *oldSelection;
}

@property (nonatomic, unsafe_unretained) EWTypewriterWindowController *owner;
@property (nonatomic, strong) NSTableView *tableView;
- (void)reloadData;
- (void)cacheSelection;
@end
