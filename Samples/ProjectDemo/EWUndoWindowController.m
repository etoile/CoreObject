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

- (IBAction) undo: (id)sender
{
	[_track undo];
}

- (IBAction) redo: (id)sender
{
	[_track redo];
}

- (void) setInspectedDocument: (Document *)aDoc
{
    _persistentRoot = [aDoc persistentRoot];
	
	OutlineController *outline = [(ApplicationDelegate *)[NSApp delegate] controllerForPersistentRoot: _persistentRoot];
	_track = [outline undoStack];
}

- (void) setUndoStack: (COUndoTrack *)stack
{
    [table reloadData];
}

- (void) undoStackDidChange: (NSNotification *)notif
{
    NSLog(@"undo track did change: %@", [notif userInfo]);
    
    NSString *stackName = [notif userInfo][kCOUndoStackName];
    
    [table reloadData];
}

- (COUndoTrack *)undoStack
{
    return _track;
}

/* Target/action */

- (void) doubleClick: (id)sender
{
	const NSUInteger row = [table selectedRow];
	if (row == NSNotFound)
		return;
	
	id<COTrackNode> node = [self nodeAtIndex: row];
	[_track setCurrentNode: node];
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
	return [nodes objectAtIndex: anIndex];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id<COTrackNode> node = [self nodeAtIndex: row];
    
    if ([[tableColumn identifier] isEqual: @"name"])
    {
        return [node localizedShortDescription];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
}

@end
