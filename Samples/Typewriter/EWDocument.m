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

- (id) initWithPersistentRoot: (COPersistentRoot *)aRoot title: (NSString *)aTitle
{
    SUPERINIT;
    
    assert(aRoot != nil);
    assert([aRoot rootObject] != nil);
    
    ASSIGN(_title, aTitle);
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
    [NSException raise: NSIllegalSelectorException format: @"use -initWithPersistentRoot:, not -init"];
    return nil;
//    
//    COPersistentRoot *aRoot = [[[NSApp delegate] editingContext] insertNewPersistentRootWithEntityName: @"Anonymous.TypewriterDocument"];
//    [aRoot commit];
//    
//    return [self initWithPersistentRoot: aRoot];
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
    [self commit];
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
    
    [self commit];
    
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
    [self commit];
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
    return _title;
//    NSString *branchName = [[_persistentRoot currentBranch] label];
//    
//    // FIXME: Get proper persistent root name
//    return [NSString stringWithFormat: @"Untitled (on branch '%@')",
//            branchName];
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
    return [_persistentRoot store];
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
    [self commit];
}

- (void) deleteBranch: (ETUUID *)aBranchUUID
{
    [_persistentRoot branchForUUID: aBranchUUID].deleted = YES;
    [self commit];
}

- (COUndoStack *)undoStack
{
    NSString *name = [NSString stringWithFormat: @"typewriter-%@",
                      [_persistentRoot persistentRootUUID]];
    
    return [[COUndoStackStore defaultStore] stackForName: name];
}

- (void) commit
{
    [[_persistentRoot editingContext] commitWithUndoStack: [self undoStack]];
}

+ (void) pullFrom: (COPersistentRoot *)source into: (COPersistentRoot *)dest
{
    COSynchronizationClient *client = [[[COSynchronizationClient alloc] init] autorelease];
    COSynchronizationServer *server = [[[COSynchronizationServer alloc] init] autorelease];
    
    id request2 = [client updateRequestForPersistentRoot: [dest persistentRootUUID]
                                                serverID: @"server"
                                                   store: [dest store]];
    id response2 = [server handleUpdateRequest: request2 store: [source store]];
    [client handleUpdateResponse: response2 store: [dest store]];
    
    // Now merge "origin/master" into "master"
    
    COPersistentRootInfo *info = [[dest store] persistentRootInfoForUUID: [dest persistentRootUUID]];
    
    ETUUID *uuid = [[[info branchInfosWithMetadataValue: [[[source currentBranch] UUID] stringValue]
                                                 forKey: @"replcatedBranch"] firstObject] UUID];
    
    COBranch *master = [dest currentBranch];
    COBranch *originMaster = [dest branchForUUID: uuid];
    assert(master != nil);
    assert([info branchInfoForUUID: uuid] != nil);
    assert(originMaster != nil);
    assert(![master isEqual: originMaster]);
    
    // FF merge?
    
    if ([COLeastCommonAncestor isRevision: [[master currentRevision] revisionID]
                equalToOrParentOfRevision: [[originMaster currentRevision] revisionID]
                                    store: [dest store]])
    {
        [master setCurrentRevision: [originMaster currentRevision]];
        [dest commit];
    }
    else
    {
        // Regular merge
        
        [master setMergingBranch: originMaster];
        
        COMergeInfo *mergeInfo = [master mergeInfoForMergingBranch: originMaster];
        assert(![mergeInfo.diff hasConflicts]);
        
        [mergeInfo.diff applyTo: [master objectGraphContext]];
        [dest commit];
    }
}

- (IBAction) push: (id)sender
{
    NSLog(@"FIXME: Not implemented");
}

- (IBAction) pull: (id)sender
{
    COPersistentRoot *user1Proot = [(EWAppDelegate *)[NSApp delegate] user1PersistentRoot];
    COPersistentRoot *user2Proot = [(EWAppDelegate *)[NSApp delegate] user2PersistentRoot];

    if ([_title isEqual: @"user2"]) // Ugly...
    {
        [EWDocument pullFrom: user1Proot into: user2Proot];
    }
    else
    {
        [EWDocument pullFrom: user2Proot into: user1Proot];
    }
}

/* EWUndoManagerDelegate */

- (void) undo
{
    [[self undoStack] undoWithEditingContext: [_persistentRoot editingContext]];
}
- (void) redo
{
    [[self undoStack] redoWithEditingContext: [_persistentRoot editingContext]];
}

- (BOOL) canUndo
{
    return [[self undoStack] canUndoWithEditingContext: [_persistentRoot editingContext]];
}
- (BOOL) canRedo
{
    return [[self undoStack] canRedoWithEditingContext: [_persistentRoot editingContext]];
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
