/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

#import "EWUndoWindowController.h"
#import "EWGraphRenderer.h"
#import <CoreObject/CoreObject.h>
#import <CoreObject/COCommandGroup.h>
#import <CoreObject/COCommandSetCurrentVersionForBranch.h>
#import <CoreObject/COEditingContext+Private.h>
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
	if (node != nil)
	{
		[_track setCurrentNode: node];
	}
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

/*
- (NSString *) detailedDescriptionOfNode: (COCommandGroup *)aCommand
{
	if ([[aCommand contents] count] != 1)
		return nil;

	if (![[[aCommand contents] firstObject] isKindOfClass: [COCommandSetCurrentVersionForBranch class]])
		return nil;
	
	COCommandSetCurrentVersionForBranch *versionChange = [[aCommand contents] firstObject];
	
	COPersistentRoot *noteProot = [_track.editingContext persistentRootForUUID: [versionChange persistentRootUUID]];
	if (noteProot == nil)
		return nil;
	
	if (![[noteProot rootObject] isKindOfClass: [TypewriterDocument class]])
		return nil;
	
	COObjectGraphContext *docGraph = [noteProot objectGraphContextForPreviewingRevision: [_track.editingContext revisionForRevisionUUID: versionChange.revisionUUID
																													 persistentRootUUID: versionChange.persistentRootUUID]];

	COObjectGraphContext *oldDocGraph = [noteProot objectGraphContextForPreviewingRevision: [_track.editingContext revisionForRevisionUUID: versionChange.oldRevisionUUID
																														persistentRootUUID: versionChange.persistentRootUUID]];
				
	
	TypewriterDocument *doc = docGraph.rootObject;
	COAttributedString *as = doc.attrString;

	TypewriterDocument *oldDoc =  oldDocGraph.rootObject;
	COAttributedString *oldAs = oldDoc.attrString;

	COAttributedStringDiff *diff = [[COAttributedStringDiff alloc] initWithFirstAttributedString: oldAs
																		  secondAttributedString: as
																						  source: nil];

	NSString *desc = [diff description];
	desc =[desc stringByReplacingOccurrencesOfString: @"\n" withString: @" "];
	return desc;
}
*/

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [graphRenderer count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	id<COTrackNode> node = [graphRenderer revisionAtIndex: row];
	if ([[tableColumn identifier] isEqualToString: @"document"])
	{
		if (node.persistentRootUUID != nil)
		{
			COPersistentRoot *proot = [_track.editingContext persistentRootForUUID: node.persistentRootUUID];
			return proot.name;
		}
		return @"";
	}
	else if ([[tableColumn identifier] isEqualToString: @"date"])
	{
		return node.date;
	}
	else if ([[tableColumn identifier] isEqualToString: @"description"])
	{
		return [node localizedShortDescription];
	}
	else
	{
		return @(row);
	}
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
