#import "EWAppDelegate.h"
#import "EWDocument.h"
#import "EWUndoManager.h"
#import "EWTypewriterWindowController.h"
#import "EWBranchesWindowController.h"
#import "EWPickboardWindowController.h"
#import "EWHistoryWindowController.h"
#import <EtoileFoundation/Macros.h>

#import <CoreObject/CoreObject.h>

@implementation EWDocument

- (id) initWithPersistentRoot: (COPersistentRoot *)aRoot
{
    SUPERINIT;
    
    ASSIGN(_persistentRoot, aRoot);
    
    EWUndoManager *myUndoManager = [[[EWUndoManager alloc] init] autorelease];
    [myUndoManager setDelegate: self];
    [self setUndoManager: (NSUndoManager *)myUndoManager];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(storePersistentRootMetadataDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: _persistentRoot];
    
    return self;
}

- (id)init
{
    COPersistentRoot *aRoot = [[[NSApp delegate] editingContext] insertNewPersistentRootWithEntityName: @"Anonymous.TypewriterDocument"];
    [aRoot commit];
    
    return [self initWithPersistentRoot: aRoot];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: COPersistentRootDidChangeNotification
                                                  object: _persistentRoot];

    [_persistentRoot release];
    [super dealloc];
}

- (void)makeWindowControllers
{
    EWTypewriterWindowController *windowController = [[[EWTypewriterWindowController alloc] initWithWindowNibName: [self windowNibName]] autorelease];
    [self addWindowController: windowController];
}

- (NSString *)windowNibName
{
    return @"EWDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return YES;
}

- (void)saveDocument:(id)sender
{
    NSLog(@"save");
}

- (IBAction) branch: (id)sender
{
    COBranch *branch = [[_persistentRoot editingBranch] makeBranchWithLabel: @"Untitled"];
    [_persistentRoot setCurrentBranch: branch];
    [[_persistentRoot editingContext] canUndoForStackNamed: @"typewriter"];
}
- (IBAction) showBranches: (id)sender
{
    [[EWBranchesWindowController sharedController] show];
}
- (IBAction) history: (id)sender
{
    [[EWHistoryWindowController sharedController] show];
}
- (IBAction) pickboard: (id)sender
{
    [[EWPickboardWindowController sharedController] show];
}

- (void) recordUpdatedItems: (NSArray *)items
{
    NSLog(@"Object graph before : %@", [[_persistentRoot editingBranch] objectGraphContext]);
    
    assert(![_persistentRoot hasChanges]);
    
    [[[_persistentRoot editingBranch] objectGraphContext] insertOrUpdateItems: items];
    
    assert([_persistentRoot hasChanges]);
    
    [[_persistentRoot editingContext] commitWithStackNamed: @"typewriter"];
    
    assert(![_persistentRoot hasChanges]);
    
    NSLog(@"Object graph after: %@", [[_persistentRoot editingBranch] objectGraphContext]);
}

- (void) validateCanLoadStateToken: (CORevisionID *)aToken
{
//    COBranch *editingBranchObject = [_persistentRoot branchForUUID: [self editingBranch]];
//    if (editingBranchObject == nil)
//    {
//        [NSException raise: NSInternalInconsistencyException
//                    format: @"editing branch %@ must be one of the persistent root's branches", editingBranch_];
//    }
//    
//    if (![[editingBranchObject allCommits] containsObject: aToken])
//    {
//        [NSException raise: NSInternalInconsistencyException
//                    format: @"the given token %@ must be in the current editing branch's list of states", aToken];
//    }
}

- (void) persistentSwitchToStateToken: (CORevisionID *)aToken
{
    [[_persistentRoot editingBranch] setCurrentRevision: [CORevision revisionWithStore: [self store]
                                                                            revisionID: aToken]];
    [[_persistentRoot editingContext] commitWithStackNamed: @"typewriter"];
}

// Doesn't write to DB...
- (void) loadStateToken: (CORevisionID *)aToken
{
    [self validateCanLoadStateToken: aToken];
         
    COBranch *editingBranchObject = [_persistentRoot editingBranch];
    CORevision *rev = [CORevision revisionWithStore: [self store]
                                         revisionID: aToken];
    
    [editingBranchObject setCurrentRevision: rev];

    NSArray *wcs = [self windowControllers];
    for (EWTypewriterWindowController *wc in wcs)
    {
        [wc displayRevision: aToken];
        [wc synchronizeWindowTitleWithDocumentName];
    }
}

- (void) setPersistentRoot: (COPersistentRoot*) aMetadata
{
    assert(aMetadata != nil);
    
    ASSIGN(_persistentRoot, aMetadata);
    [self loadStateToken: [[[_persistentRoot currentBranch] currentRevision] revisionID]];
}

- (NSString *)displayName
{
    NSString *branchName = [[_persistentRoot currentBranch] label];
    
    // FIXME: Get proper persistent root name
    return [NSString stringWithFormat: @"Untitled (on branch '%@')",
            branchName];
}

- (void) reloadFromStore
{
    // Reads the UUID of _persistentRoot, and uses that to reload the rest of the metadata
    
    ETUUID *uuid = [self UUID];
    
    //[self setPersistentRoot: [store_ persistentRootWithUUID: uuid]];
}

- (ETUUID *) editingBranch
{
    return [[_persistentRoot editingBranch] UUID];
}

- (COPersistentRoot *) currentPersistentRoot
{
    return _persistentRoot;
}

- (ETUUID *) UUID
{
    return [_persistentRoot persistentRootUUID];
}

- (COSQLiteStore *) store
{
    return [[NSApp delegate] store];
}

- (void) storePersistentRootMetadataDidChange: (NSNotification *)notif
{
    NSLog(@"did change: %@", notif);
    
    [self loadStateToken: [[[_persistentRoot currentBranch] currentRevision] revisionID]];
}

- (void) switchToBranch: (ETUUID *)aBranchUUID
{
    COBranch *branch = [_persistentRoot branchForUUID: aBranchUUID];
    [_persistentRoot setCurrentBranch: branch];
    [[_persistentRoot editingContext] commitWithStackNamed: @"typewriter"];
}

- (void) deleteBranch: (ETUUID *)aBranchUUID
{
    [_persistentRoot deleteBranch: [_persistentRoot branchForUUID: aBranchUUID]];
    [[_persistentRoot editingContext] commitWithStackNamed: @"typewriter"];
}

/* EWUndoManagerDelegate */

- (void) undo
{
    [[_persistentRoot editingContext] undoForStackNamed: @"typewriter"];
}
- (void) redo
{
    [[_persistentRoot editingContext] redoForStackNamed: @"typewriter"];}

- (BOOL) canUndo
{
    return [[_persistentRoot editingContext] canUndoForStackNamed: @"typewriter"];
}
- (BOOL) canRedo
{
    return [[_persistentRoot editingContext] canRedoForStackNamed: @"typewriter"];
}

- (NSString *) undoMenuItemTitle
{
    return @"Undo";
}
- (NSString *) redoMenuItemTitle
{
    return @"Redo";
}

@end
