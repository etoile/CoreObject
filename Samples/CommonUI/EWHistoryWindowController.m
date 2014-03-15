/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  March 2014
	License:  MIT  (see COPYING)
 */

#import "EWHistoryWindowController.h"
#import "EWGraphRenderer.h"
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/Macros.h>
#import <CoreObject/COEditingContext+Private.h>

@implementation EWHistoryWindowController

- (instancetype) initWithInspectedPersistentRoot: (COPersistentRoot *)aPersistentRoot undoTrack: (COUndoTrack *)aTrack
{
	self = [super initWithWindowNibName: @"History"];
    if (self)
	{
		inspectedPersistentRoot = aPersistentRoot;
		inspectedBranch = inspectedPersistentRoot.currentBranch;
		undoTrackToCommitTo = aTrack;
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(persistentRootDidChange:)
                                                     name: COPersistentRootDidChangeNotification
                                                   object: aPersistentRoot];
		
		
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) awakeFromNib
{
	graphRenderer.delegate = self;
	
    [table setDoubleAction: @selector(doubleClick:)];
    [table setTarget: self];
	
	[self update];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [NSString stringWithFormat: @"%@ History", inspectedPersistentRoot.metadata[@"label"]];
}

- (void) update
{
	inspectedBranch = inspectedPersistentRoot.currentBranch;
	
	[graphRenderer updateWithTrack: inspectedBranch];
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

- (void) persistentRootDidChange: (NSNotification *)notif
{
    NSLog(@"persistent root did change: %@", [notif userInfo]);
	
    [self update];
}

// FIXME: Copied from EWUndoWindowController
- (void) validateButtons
{
	[undo setEnabled: [inspectedBranch canUndo]];
	[redo setEnabled: [inspectedBranch canRedo]];
	
	id<COTrackNode> highlightedNode = [self selectedNode];
	
	const NSUInteger highlightedNodeIndex = [[inspectedBranch nodes] indexOfObject: highlightedNode];
	const NSUInteger currentNodeIndex = [[inspectedBranch nodes] indexOfObject: [inspectedBranch currentNode]];
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
	[inspectedBranch setCurrentNode: node];
	[self commitWithIdentifier: @"revert" descriptionArguments: @[]];
}

- (IBAction) undo: (id)sender
{
	[inspectedBranch undo];
	[self commitWithIdentifier: @"step-backward" descriptionArguments: @[]];
}

- (IBAction) redo: (id)sender
{
	[inspectedBranch redo];
	[self commitWithIdentifier: @"step-forward" descriptionArguments: @[]];
}

- (IBAction) selectiveUndo: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	if (node != nil)
	{
		[inspectedBranch undoNode: node];
		NSString *desc = [node localizedShortDescription] != nil ? [node localizedShortDescription] : @"";
		[self commitWithIdentifier: @"selective-undo" descriptionArguments: @[desc]];
	}
}

- (IBAction) selectiveRedo: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	if (node != nil)
	{
		[inspectedBranch redoNode: node];
		NSString *desc = [node localizedShortDescription] != nil ? [node localizedShortDescription] : @"";
		[self commitWithIdentifier: @"selective-redo" descriptionArguments: @[desc]];
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

- (void) commitWithIdentifier: (NSString *)identifier descriptionArguments: (NSArray*)args
{
	NSMutableDictionary *metadata = [NSMutableDictionary new];
	if (args != nil)
		metadata[kCOCommitMetadataShortDescriptionArguments] = args;
	
	if ([undoTrackToCommitTo isCoalescing])
		[undoTrackToCommitTo endCoalescing];
	
	[inspectedPersistentRoot.editingContext commitWithIdentifier: [@"org.etoile.CoreObject." stringByAppendingString: identifier]
														metadata: metadata
													   undoTrack: undoTrackToCommitTo
														   error: NULL];
}


/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [graphRenderer count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	id<COTrackNode> node = [graphRenderer revisionAtIndex: row];
	if ([[tableColumn identifier] isEqualToString: @"date"])
	{
		return node.date;
	}
	else if ([[tableColumn identifier] isEqualToString: @"description"])
	{
		return [node localizedShortDescription];
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

- (NSArray *) allOrderedNodesToDisplayForTrack: (id<COTrack>)aTrack
{
	ETAssert(aTrack == inspectedBranch);
	COPersistentRoot *proot = ((COBranch *)aTrack).persistentRoot;

	// UGLY: Relies on the output of -revisionInfosForBackingStoreOfPersistentRootUUID: already being sorted
	NSArray *revInfos = [proot.store revisionInfosForBackingStoreOfPersistentRootUUID: proot.UUID];
	revInfos = [[revInfos reverseObjectEnumerator] allObjects];
	NSArray *revisions = [revInfos mappedCollectionWithBlock: ^(id obj) {
		CORevisionInfo *revInfo = obj;
		return [inspectedPersistentRoot.editingContext revisionForRevisionUUID: revInfo.revisionUUID
															persistentRootUUID: revInfo.persistentRootUUID];
	}];

	return revisions;
}

@end
