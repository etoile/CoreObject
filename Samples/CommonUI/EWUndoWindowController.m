#import "EWUndoWindowController.h"
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/Macros.h>

@implementation EWUndoWindowController

- (id)init
{
	self = [super initWithWindowNibName: @"Undo"];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(undoStackDidChange:)
                                                     name: COUndoStackDidChangeNotification
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
	
	[self update];
}

- (void) update
{
    [table reloadData];
	[self validateButtons];
		
	if ([table numberOfRows] > 0)
	{
		NSUInteger idx = [[_track nodes] indexOfObject: [_track currentNode]];
		if (idx != NSNotFound)
		{
			[table scrollRowToVisible: idx];
		}
		else
		{
			[table scrollRowToVisible: [table numberOfRows] - 1];
		}
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

- (void) undoStackDidChange: (NSNotification *)notif
{
    NSLog(@"undo track did change: %@", [notif userInfo]);
	
    [self update];
}

- (void) validateButtons
{
	[undo setEnabled: [_track canUndo]];
	[redo setEnabled: [_track canRedo]];
	
	[selectiveUndo setEnabled: NO];
	[selectiveRedo setEnabled: NO];
	
	id<COTrackNode> highlightedNode = [self selectedNode];
	const NSUInteger highlightedNodeIndex = [[_track nodes] indexOfObject: highlightedNode];
	const NSUInteger currentNodeIndex = [[_track nodes] indexOfObject: [_track currentNode]];
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
	[_track setCurrentNode: node];
}

- (IBAction) undo: (id)sender
{
	[_track undo];
}

- (IBAction) redo: (id)sender
{
	[_track redo];
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
	const NSUInteger row = [table selectedRow];
	if (row == NSNotFound)
		return nil;
	
	id<COTrackNode> node = [self nodeAtIndex: row];
	return node;
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    const NSUInteger count = [[_track nodes] count];
    return count;
}

- (id<COTrackNode>) nodeAtIndex: (NSUInteger)anIndex
{
    NSArray *nodes = [_track nodes];
	
	if (anIndex >= [nodes count])
		return nil;
	
	return [nodes objectAtIndex: anIndex];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id<COTrackNode> node = [self nodeAtIndex: row];
    
    if ([[tableColumn identifier] isEqual: @"name"])
    {
        return [node localizedShortDescription];
    }
	else if ([[tableColumn identifier] isEqual: @"isCurrent"])
    {
        if ([[_track currentNode] isEqual: node])
		{
			return @YES;
		}
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	id<COTrackNode> node = [self nodeAtIndex: row];
	
	if ([[tableColumn identifier] isEqual: @"isCurrent"])
    {
		if ([object boolValue] && node != nil)
		{
			[_track setCurrentNode: node];
		}
    }
}

/* NSTableViewDelegate */

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self validateButtons];
}

@end
