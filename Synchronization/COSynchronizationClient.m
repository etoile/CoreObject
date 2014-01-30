/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizationClient.h"


#import "COSQLiteStore.h"
#import "COSQLiteStore+Private.h"
#import "COStoreTransaction.h"

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
        [clientNewestRevisionIDForBranchUUID setObject: [[branch currentRevisionUUID] stringValue]
                                                forKey: [[branch UUID] stringValue]];
    }
    
    return @{@"clientNewestRevisionIDForBranchUUID" : clientNewestRevisionIDForBranchUUID,
             @"persistentRoot" : [aRoot stringValue],
             @"serverID" : anID};
}

static ETUUID *RevisionUUIDFromString(NSString *aRevisionUUID)
{
    if (aRevisionUUID != nil)
    {
        ETUUID *uuid = [ETUUID UUIDWithString: aRevisionUUID];
        return uuid;
    }
    return nil;
}

static void DFSInsertRevisions(NSMutableSet *revisionUUIDsToHandle, ETUUID *revisionUUID, NSDictionary *revisionsPlist, COStoreTransaction *txn, ETUUID *persistentRoot)
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
        DFSInsertRevisions(revisionUUIDsToHandle, [ETUUID UUIDWithString: parentString], revisionsPlist, txn, persistentRoot);
    }    
    if (mergeParentString != nil)
    {
        DFSInsertRevisions(revisionUUIDsToHandle, [ETUUID UUIDWithString: mergeParentString], revisionsPlist, txn, persistentRoot);
    }
 
    // Now both parents are inserted, or were already in our store.
    
    id metadata = revDict[@"info"][@"metadata"];
    COItemGraph *graph = COItemGraphFromJSONPropertyLisy(revDict[@"graph"]);
    
    ETUUID *parentRevid = RevisionUUIDFromString(parentString);
    ETUUID *mergeParentRevid = RevisionUUIDFromString(mergeParentString);
	ETUUID *branchUUID = [ETUUID UUIDWithString: revDict[@"info"][@"branchUUID"]];
	
	[txn writeRevisionWithModifiedItems: graph
						   revisionUUID: revisionUUID
							   metadata: metadata
					   parentRevisionID: parentRevid
				  mergeParentRevisionID: mergeParentRevid
					 persistentRootUUID: persistentRoot
							 branchUUID: branchUUID];
}

static void InsertRevisions(NSDictionary *revisionsPlist, COStoreTransaction *txn, ETUUID *persistentRoot)
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
                           revisionsPlist, txn, persistentRoot);
    }
}

- (void) handleUpdateResponse: (NSDictionary *)aResponse
                        store: (COSQLiteStore *)aStore
{
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    
    NSString *serverID = aResponse[@"serverID"];
    ETUUID *persistentRoot = [ETUUID UUIDWithString: aResponse[@"persistentRoot"]];
    
    // 1. Do we have this persistent root?
    
    COPersistentRootInfo *info = [aStore persistentRootInfoForUUID: persistentRoot];
    if (info == nil)
    {
        // No: create it
        
		[txn createPersistentRootWithUUID: persistentRoot persistentRootForCopy: nil];
		
        info = [[COPersistentRootInfo alloc] init];
		info.UUID = persistentRoot;
    }
    
    // Insert the revisions the server sent us.
    
    InsertRevisions(aResponse[@"revisions"], txn, persistentRoot);

    ETUUID *currentBranchUUID = [ETUUID UUIDWithString: aResponse[@"currentBranchUUID"]];
    ETUUID *replicatedServerCurrentRevision = nil;
    
    for (NSString *branchUUIDString in aResponse[@"branches"])
    {
        NSDictionary *branchPlist = aResponse[@"branches"][branchUUIDString];
    
        // Search for a previously synced branch to update
        
        COBranchInfo *branchToUpdate = nil;
        
        for (COBranchInfo *branch in [info branches])
        {
            if ([[branch metadata][@"source"] isEqual: serverID]
                && [[branch metadata][@"replcatedBranch"] isEqual: branchUUIDString])
            {
                branchToUpdate = branch;
                break;
            }
        }
        
        ETUUID *currentRevisionID = [ETUUID UUIDWithString: branchPlist[@"currentRevisionID"]];

        ETUUID *branchUUID;
        
        if (branchToUpdate == nil)
        {
            // None found, create a new one
            
            branchUUID = [ETUUID UUID];
            
            [txn createBranchWithUUID: branchUUID
						 parentBranch: nil
					  initialRevision: currentRevisionID
					forPersistentRoot: persistentRoot];
            
            [txn setMetadata: @{ @"source" : serverID, @"replcatedBranch" : branchUUIDString }
				   forBranch: branchUUID
			ofPersistentRoot: persistentRoot];
        }
        else
        {
            branchUUID = [branchToUpdate UUID];
        }
        
        [txn setCurrentRevision: currentRevisionID
				   headRevision: currentRevisionID
					  forBranch: branchUUID
			   ofPersistentRoot: persistentRoot];
        
        if ([branchUUIDString isEqualToString: aResponse[@"currentBranchUUID"]])
        {
            replicatedServerCurrentRevision = currentRevisionID;
        }
    }
    
    // Set a default current branch if there is not one

    if ([info currentBranchUUID] == nil)
    {
        [txn createBranchWithUUID: currentBranchUUID
					 parentBranch: nil
				  initialRevision: replicatedServerCurrentRevision
				forPersistentRoot: persistentRoot];
        
        [txn setCurrentBranch: currentBranchUUID
			forPersistentRoot: persistentRoot];
    }
    
	[txn setOldTransactionID: info.transactionID forPersistentRoot: persistentRoot];
	
    BOOL ok = [aStore commitStoreTransaction: txn];
	
	ETAssert(ok);
}

@end
