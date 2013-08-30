#import "COSynchronizationClient.h"


#import "COSQLiteStore.h"

@implementation COSynchronizationClient

/**
 * Make a request to send to the server
 */
- (NSDictionary *) updateRequestForPersistentRoot: (ETUUID *)aRoot
                                         serverID: (NSString*)anID
                                            store: (COSQLiteStore *)aStore
{
    // info may be nil
    COPersistentRootInfo *info = [aStore persistentRootInfoForUUID: aRoot];
    
    NSMutableDictionary *clientNewestRevisionIDForBranchUUID = [NSMutableDictionary dictionary];
    for (COBranchInfo *branch in [info branches])
    {
        // N.B. Only send the server the revision UUID - backing store UUIDs are implementation details of the store
        // and two stores may not use the same backing UUID for a persistent root.
        //
        // Note that we tell the server end the persistent root that the revisions belong to.
        [clientNewestRevisionIDForBranchUUID setObject: [[[branch headRevisionID] revisionUUID] stringValue]
                                                forKey: [[branch UUID] stringValue]];
    }
    
    return @{@"clientNewestRevisionIDForBranchUUID" : clientNewestRevisionIDForBranchUUID,
             @"persistentRoot" : [aRoot stringValue],
             @"serverID" : anID};
}

static CORevisionID *RevisionIDForRevisionUUID(NSString *aRevisionUUID, ETUUID *persistentRoot, COSQLiteStore *aStore)
{
    if (aRevisionUUID != nil)
    {
        ETUUID *uuid = [ETUUID UUIDWithString: aRevisionUUID];
        CORevisionID *revid = [aStore revisionIDForRevisionUUID: uuid persistentRootUUID: persistentRoot];
        return revid;
    }
    return nil;
}

static void DFSInsertRevisions(NSMutableSet *revisionUUIDsToHandle, ETUUID *revisionUUID, NSDictionary *revisionsPlist, COSQLiteStore *store, ETUUID *persistentRoot)
{
    if (![revisionUUIDsToHandle containsObject: revisionUUID])
    {
        // FIXME: We could assert that revisionUUID is in the store
        return;
    }
    
    [revisionUUIDsToHandle removeObject: revisionUUID];
 
    // Make sure the parents are inserted
    
    NSDictionary *revDict = revisionsPlist[[revisionUUID stringValue]];
    
    NSString *parentString = revDict[@"info"][@"parent"];
    NSString *mergeParentString = revDict[@"info"][@"mergeParent"];
    
    if (parentString != nil)
    {
        DFSInsertRevisions(revisionUUIDsToHandle, [ETUUID UUIDWithString: parentString], revisionsPlist, store, persistentRoot);
    }    
    if (mergeParentString != nil)
    {
        DFSInsertRevisions(revisionUUIDsToHandle, [ETUUID UUIDWithString: mergeParentString], revisionsPlist, store, persistentRoot);
    }
 
    // Now both parents are inserted, or were already in our store.
    
    id metadata = revDict[@"info"][@"metadata"];
    id<COItemGraph> graph = COItemGraphFromJSONPropertyLisy(revDict[@"graph"]);
    
    CORevisionID *parentRevid = RevisionIDForRevisionUUID(parentString, persistentRoot, store);
    CORevisionID *mergeParentRevid = RevisionIDForRevisionUUID(mergeParentString, persistentRoot, store);
    
    CORevisionID *revid = [store writeRevisionWithItemGraph: graph
                                                   metadata: metadata
                                           parentRevisionID: parentRevid
                                      mergeParentRevisionID: mergeParentRevid
                                         persistentRootUUID: persistentRoot
                                              modifiedItems: nil
                                                      error: NULL];
    assert(revid != nil);
}

static void InsertRevisions(NSDictionary *revisionsPlist, COSQLiteStore *store, ETUUID *persistentRoot)
{
    NSMutableSet *revisionUUIDsToHandle = [NSMutableSet set];
    for (NSString *revisionUUIDString in revisionsPlist)
    {
        [revisionUUIDsToHandle addObject: [ETUUID UUIDWithString: revisionUUIDString]];
    }
    
    if ([revisionUUIDsToHandle isEmpty])
    {
        return;
    }
    
    while (![revisionUUIDsToHandle isEmpty])
    {
        DFSInsertRevisions(revisionUUIDsToHandle, [revisionUUIDsToHandle anyObject],
                           revisionsPlist, store, persistentRoot);
    }
}

- (void) handleUpdateResponse: (NSDictionary *)aResponse
                        store: (COSQLiteStore *)aStore
{
    ETUUID *persistentRoot = [ETUUID UUIDWithString: aResponse[@"persistentRoot"]];
    
    // 1. Do we have this persistent root?
    
    COPersistentRootInfo *info = [aStore persistentRootInfoForUUID: persistentRoot];
    if (info == nil)
    {
        // No: create it
        
        info = [aStore createPersistentRootWithUUID: persistentRoot error: NULL];
        assert(info != nil);
    }
    
    // Insert the revisions the server sent us.
    
    InsertRevisions(aResponse[@"revisions"], aStore, persistentRoot);
    
    // Update the branch
}

@end
