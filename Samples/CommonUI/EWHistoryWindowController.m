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

- (void) validateButtons
{
	[undo setEnabled: [inspectedBranch canUndo]];
	[redo setEnabled: [inspectedBranch canRedo]];
	
	[selectiveUndo setEnabled: NO];
	[selectiveRedo setEnabled: NO];
	
	id<COTrackNode> highlightedNode = [self selectedNode];
	const NSUInteger highlightedNodeIndex = [[inspectedBranch nodes] indexOfObject: highlightedNode];
	const NSUInteger currentNodeIndex = [[inspectedBranch nodes] indexOfObject: [inspectedBranch currentNode]];
	const BOOL canSelectiveUndo = (highlightedNode != nil
								   && highlightedNode != [COEndOfUndoTrackPlaceholderNode sharedInstance]
								   && highlightedNodeIndex != NSNotFound
								   && highlightedNodeIndex < currentNodeIndex);
	[selectiveUndo setEnabled: canSelectiveUndo];
}

/* Target/action */

- (void) doubleClick: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	[inspectedBranch setCurrentNode: node];
}

- (IBAction) undo: (id)sender
{
	[inspectedBranch undo];
}

- (IBAction) redo: (id)sender
{
	[inspectedBranch redo];
}

- (IBAction) selectiveUndo: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	if (node != nil)
	{
		[inspectedBranch undoNode: node];
	}
}

- (IBAction) selectiveRedo: (id)sender
{
	id<COTrackNode> node = [self selectedNode];
	if (node != nil)
	{
		[inspectedBranch redoNode: node];
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
	if ([[tableColumn identifier] isEqualToString: @"date"])
	{
		id<COTrackNode> node = [graphRenderer revisionAtIndex: row];
		return node.date;
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

static NSArray *RevisionInfosChronological(NSSet *commits)
{
    return [[commits allObjects] sortedArrayUsingComparator: ^(id obj1, id obj2) {
        CORevisionInfo *obj1Info = obj1;
        CORevisionInfo *obj2Info = obj2;
        
        return [[obj2Info date] compare: [obj1Info date]];
    }];
}

static NSSet *RevisionInfoSet(COPersistentRoot *proot)
{
	NSSet *revisionInfos = [NSSet setWithArray:
							[proot.store revisionInfosForBackingStoreOfPersistentRootUUID: proot.UUID]];
	
	return revisionInfos;
}

- (NSArray *) allOrderedNodesToDisplayForTrack: (id<COTrack>)aTrack
{
	ETAssert(aTrack == inspectedBranch);
	NSSet *revisionInfoSet = RevisionInfoSet(inspectedPersistentRoot);
	NSArray *revInfos = RevisionInfosChronological(revisionInfoSet);
	
	NSArray *revisions = [revInfos mappedCollectionWithBlock: ^(id obj) {
		CORevisionInfo *revInfo = obj;
		return [inspectedPersistentRoot.editingContext revisionForRevisionUUID: revInfo.revisionUUID
															persistentRootUUID: revInfo.persistentRootUUID];
	}];

	return revisions;
}

@end
