#import "EWUndoWindowController.h"
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/Macros.h>

#import "EWDocument.h"

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

+ (EWUndoWindowController *) sharedController
{
    static EWUndoWindowController *shared;
    if (shared == nil) {
        shared = [[self alloc] init];
    }
    return shared;
}

- (void) awakeFromNib
{
    [table setDoubleAction: @selector(doubleClick:)];
    [table setTarget: self];
}

- (IBAction) undo: (id)sender
{
    [_inspectedDocument undo];
}

- (IBAction) redo: (id)sender
{
    [_inspectedDocument redo];
}

- (void) setInspectedDocument: (NSDocument *)aDoc
{
    NSLog(@"Inspect %@", aDoc);
    
    _inspectedDocument = (EWDocument *)aDoc;
    
    [self setUndoStack: [_inspectedDocument undoStack]];
    [stackLabel setStringValue: [[_inspectedDocument undoStack] name]];
}

- (void) setUndoStack: (COUndoStack *)stack
{
    [table reloadData];
}

- (void) show
{
    [self showWindow: self];
    [self setInspectedDocument: [[NSDocumentController sharedDocumentController]
                                 currentDocument]];
}
//
//- (COBranch *)selectedBranch
//{
//    COBranch *branch = [[self orderedBranches] objectAtIndex: [table selectedRow]];
//    return branch;
//}
//
//- (void)doubleClick: (id)sender
//{
//	if (sender == table)
//	{
//		COBranch *branch = [self selectedBranch];
//		
//        [(EWDocument *)[[NSDocumentController sharedDocumentController]
//          currentDocument] switchToBranch: [branch UUID]];
//	}
//}

- (void) undoStackDidChange: (NSNotification *)notif
{
    NSLog(@"Undo stack did change: %@", [notif userInfo]);
    
    NSString *stackName = [notif userInfo][kCOUndoStackName];
    
    [table reloadData];
}

- (COUndoStack *)undoStack
{
    return [_inspectedDocument undoStack];
}

/* NSTableViewDataSource */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    COUndoStack *stack = [self undoStack];
    
    NSUInteger undoNodes = [[stack undoNodes] count];
    NSUInteger redoNodes = [[stack redoNodes] count];
    
    return undoNodes + redoNodes;
}

- (id<COUndoNode>) nodeAtIndex: (NSUInteger)anIndex
{
    COUndoStack *stack = [self undoStack];
    
    NSArray *undoNodes = [stack undoNodes];
    NSArray *redoNodes = [stack redoNodes];
    
    NSUInteger undoNodesCount = [[stack undoNodes] count];
    NSUInteger redoNodesCount = [[stack redoNodes] count];

    if (anIndex < redoNodesCount)
    {
        return [redoNodes objectAtIndex: (redoNodesCount - 1 - anIndex)];
    }
    else
    {
        return [undoNodes objectAtIndex: anIndex - redoNodesCount];
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id<COUndoNode> node = [self nodeAtIndex: row];
    
    if ([[tableColumn identifier] isEqual: @"name"])
    {
        return node;
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
}

@end
