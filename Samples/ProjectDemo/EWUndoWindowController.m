#import "EWUndoWindowController.h"
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/Macros.h>
#import "ApplicationDelegate.h"
#import "OutlineController.h"

#import "Document.h"

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
}

- (void) setInspectedDocument: (Document *)aDoc
{
	NSLog(@"UndoWindow: set inspected document");
	
    _persistentRoot = [aDoc persistentRoot];
	
	OutlineController *outline = [(ApplicationDelegate *)[NSApp delegate] controllerForPersistentRoot: _persistentRoot];
	[self setUndoStack: [outline undoStack]];
}

- (void) setUndoStack: (COUndoTrack *)stack
{
	_track = stack;
	NSLog(@"Set undo stack %@ has %d items", _track, (int)[[_track nodes] count]);
    [table reloadData];
	[self validateButtons];
}

- (void) undoStackDidChange: (NSNotification *)notif
{
    NSLog(@"undo track did change: %@", [notif userInfo]);
	
    OutlineController *outline = [(ApplicationDelegate *)[NSApp delegate] controllerForPersistentRoot: _persistentRoot];
	[self setUndoStack: [outline undoStack]];
}

- (COUndoTrack *)undoStack
{
    return _track;
}

- (void) validateButtons
{
	[undo setEnabled: [_track canUndo]];
	[redo setEnabled: [_track canRedo]];
	
	[selectiveUndo setEnabled: NO];
	[selectiveRedo setEnabled: NO];
	
	id<COTrackNode> node = [self selectedNode];
	const NSUInteger currentNodeIndex = [[_track nodes] indexOfObject: [_track currentNode]];
	const NSUInteger nodeIndex = [[_track nodes] indexOfObject: node];

	if (node != nil && nodeIndex != NSNotFound)
	{
		[selectiveUndo setEnabled: nodeIndex <= currentNodeIndex];
		[selectiveRedo setEnabled: nodeIndex > currentNodeIndex];
	}
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
	return;
	
	id<COTrackNode> node = [self nodeAtIndex: row];
	return node;
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    COUndoTrack *stack = [self undoStack];
    const NSUInteger count = [[stack nodes] count];
    return count;
}

- (id<COTrackNode>) nodeAtIndex: (NSUInteger)anIndex
{
    COUndoTrack *stack = [self undoStack];
    NSArray *nodes = [stack nodes];
	
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
