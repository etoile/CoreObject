/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

#import "EWUndoWindowController.h"
#import "EWGraphRenderer.h"
#import <CoreObject/CoreObject.h>
#import <CoreObject/COCommandGroup.h>
#import <EtoileFoundation/Macros.h>

@implementation EWUndoWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"Undo"];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(undoTrackDidChange:)
                                                     name: COUndoTrackDidChangeNotification
                                                   object: nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) awakeFromNib
{
    [table setDoubleAction: @selector(doubleClick:)];
    [table setTarget: self];
	graphRenderer.delegate = self;
	
	[self update];
}

- (void) update
{
	[graphRenderer updateWithTrack: _track];
    [table reloadData];
	[self validateButtons];
		
	if ([table numberOfRows] > 0)
	{
//		NSUInteger idx = [[_track nodes] indexOfObject: [_track currentNode]];
//		if (idx != NSNotFound)
//		{
//			[table scrollRowToVisible: idx];
//		}
//		else
//		{
//			[table scrollRowToVisible: [table numberOfRows] - 1];
//		}
	}
}

- (COUndoTrack *)undoTrack
{
	return _track;
}

- (void) setInspectedWindowController: (NSWindowController *)aDoc
{
	NSLog(@"UndoWindow: set inspected document");

	if ([aDoc respondsToSelector: @selector(undoTrack)])
	{
		wc = aDoc;
		_track = [aDoc performSelector: @selector(undoTrack)];
	}
	else
	{
		wc = nil;
		_track = nil;
	}
	
	[self update];
}

- (void) undoTrackDidChange: (NSNotification *)notif
{
    NSLog(@"undo track did change: %@", [notif userInfo]);
	
    [self update];
}

- (void) validateButtons
{
	[undo setEnabled: [_track canUndo]];
	[redo setEnabled: [_track canRedo]];
	
	id<COTrackNode> highlightedNode = [self selectedNode];
		
	const NSUInteger highlightedNodeIndex = [[_track nodes] indexOfObject: highlightedNode];
	const NSUInteger currentNodeIndex = [[_track nodes] indexOfObject: [_track currentNode]];
	const BOOL canSelectiveUndo = (highlightedNode != nil
								   && highlightedNode != [COEndOfUndoTrackPlaceholderNode sharedInstance]
								   && highlightedNodeIndex != NSNotFound
								   && highlightedNodeIndex < currentNodeIndex);
	
	const BOOL canSelectiveRedo = (!canSelectiveUndo
								   && highlightedNode != nil
								   && highlightedNode != [COEndOfUndoTrackPlaceholderNode sharedInstance]
								   && highlightedNodeIndex != currentNodeIndex);
	
	if (canSelectiveUndo)
	{
		[selectiveUndo setEnabled: YES];
		[selectiveUndo setTitle: @"Selective Undo"];
		[selectiveUndo setAction: @selector(selectiveUndo:)];
	}
	else if (canSelectiveRedo)
	{
		[selectiveUndo setEnabled: YES];
		[selectiveUndo setTitle: @"Selective Redo"];
		[selectiveUndo setAction: @selector(selectiveRedo:)];
	}
	else
	{
		[selectiveUndo setEnabled: NO];
	}
}

/* Target/action */

- (void) doubleClick: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	[_track setCurrentNode: node];
}

- (IBAction) selectiveUndo: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	if (node != nil)
	{
		[_track undoNode: node];
	}
}

- (IBAction) selectiveRedo: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	if (node != nil)
	{
		[_track redoNode: node];
	}
}

/* Convenience */

- (id<COTrackNode>) selectedNode
{
	const NSInteger row = [table selectedRow];
	if (row == -1)
		return nil;
	
	id<COTrackNode> node = [graphRenderer revisionAtIndex: row];
	return node;
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [graphRenderer count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if ([[tableColumn identifier] isEqualToString: @"document"])
	{
		id<COTrackNode> node = [graphRenderer revisionAtIndex: row];
		if (node.persistentRootUUID != nil)
		{
			COPersistentRoot *proot = [_track.editingContext persistentRootForUUID: node.persistentRootUUID];
			return proot.metadata[@"label"];
		}
		return @"";
	}
	return @(row);
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
}

/* NSTableViewDelegate */

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self validateButtons];
}

#pragma mark - EWGraphRenderedDelegate

static NSArray *sortTrackNodes(NSArray *commits)
{
    return [commits sortedArrayUsingComparator: ^(id obj1, id obj2) {
        COCommandGroup *obj1Info = obj1;
        COCommandGroup *obj2Info = obj2;

        if (obj2Info.sequenceNumber < obj1Info.sequenceNumber)
			return NSOrderedAscending;
		else if (obj2Info.sequenceNumber > obj1Info.sequenceNumber)
			return NSOrderedDescending;
		else
			return NSOrderedSame;
	}];
}

- (NSArray *) allOrderedNodesToDisplayForTrack: (id<COTrack>)aTrack
{
	NSArray *allCommands = [_track allCommands];
	return sortTrackNodes(allCommands);
}

@end
