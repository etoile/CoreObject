#import "COSynchronizationServer.h"

#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSynchronizationServer

static void SearchForRevisionsClientLacks(NSMutableSet *resultSet, ETUUID *rev, ETUUID *persistentRootUUID, NSSet *clientLatestRevisions, COSQLiteStore *store)
{
    if ([clientLatestRevisions containsObject: rev])
    {
        return;
    }
    
    [resultSet addObject: rev];
    
    // Recursively search the parent(s)
    
    CORevisionInfo *info = [store revisionInfoForRevisionUUID: rev persistentRootUUID: persistentRootUUID];
    if ([info parentRevisionID] != nil)
    {
        SearchForRevisionsClientLacks(resultSet, [info parentRevisionUUID], persistentRootUUID, clientLatestRevisions, store);
    }
    if ([info mergeParentRevisionID] != nil)
    {
        SearchForRevisionsClientLacks(resultSet, [info mergeParentRevisionUUID], persistentRootUUID, clientLatestRevisions, store);
    }
}

/*

For each branch the client tells us about:
Do we have the revision they report as being their latest? if not, assume they
are ahead of us for that branch, and ignore it

Next, start depth-first searches rooted at the latest revisions on each of our branches.
stop a branch of the search when we hit one of their revisions. This should collect the
set of revisions we want to send to the client.
 
The client has to tell us all of its branches, but we don't need to sync everything down to them.
For now we do.
 
 */
- (NSDictionary *) handleUpdateRequest: (NSDictionary *)aRequest
                                 store: (COSQLiteStore *)aStore
{
    ETUUID *persistentRoot = [ETUUID UUIDWithString: aRequest[@"persistentRoot"]];
    COPersistentRootInfo *serverInfo = [aStore persistentRootInfoForUUID: persistentRoot];
    
    // 1. Gather a set of CORevisionID that represent the "heads" of all of the clients' branches
    NSMutableSet *clientLatestRevisions = [NSMutableSet set];
    for (NSString *revisionUUIDString in [[aRequest objectForKey: @"clientNewestRevisionIDForBranchUUID"] allValues])
    {
        ETUUID *revid = [ETUUID UUIDWithString: revisionUUIDString];

        [clientLatestRevisions addObject: revid];
    }
    
    // 2. Calculate the set of CORevisionID that the client lacks
    NSMutableSet *revisionsClientLacks = [NSMutableSet set];
    for (COBranchInfo *branch in [serverInfo branches])
    {
        SearchForRevisionsClientLacks(revisionsClientLacks, [branch currentRevisionUUID], persistentRoot, clientLatestRevisions, aStore);
    }
    
    // Now prepare the property list output
    
    NSMutableDictionary *branches = [NSMutableDictionary dictionary];
    for (COBranchInfo *branch in [serverInfo branches])
    {
        if (branch.metadata[@"source"] != nil)
        {
            continue;
        }
        NSMutableDictionary *branchPlist = [NSMutableDictionary dictionary];
        branchPlist[@"uuid"] = [branch.UUID stringValue];
        branchPlist[@"initialRevisionID"] = [[branch.initialRevisionID revisionUUID] stringValue];
        branchPlist[@"currentRevisionID"] = [[branch.currentRevisionID revisionUUID] stringValue];
        if (branch.metadata != nil)
        {
            branchPlist[@"metadata"] = branch.metadata;
        }
        
        [branches setObject: branchPlist
                     forKey: [[branch UUID] stringValue]];
    }
    
    NSMutableDictionary *contentsForRevisionID = [NSMutableDictionary dictionary];
    for (ETUUID *revid in revisionsClientLacks)
    {
        id<COItemGraph> graph = [aStore itemGraphForRevisionUUID: revid persistentRoot: persistentRoot];
        CORevisionInfo *revInfo = [aStore revisionInfoForRevisionUUID: revid persistentRootUUID: persistentRoot];
        
        NSMutableDictionary *revInfoPlist = [NSMutableDictionary dictionary];
        if (revInfo.parentRevisionID != nil)
        {
            revInfoPlist[@"parent"] = [revInfo.parentRevisionID.revisionUUID stringValue];
        }
        if (revInfo.mergeParentRevisionID != nil)
        {
            revInfoPlist[@"mergeParent"] = [revInfo.mergeParentRevisionID.revisionUUID stringValue];
        }
        if (revInfo.metadata != nil)
        {
            revInfoPlist[@"metadata"] = revInfo.metadata;
        }
		revInfoPlist[@"branchUUID"] = [revInfo.branchUUID stringValue];
        
        id graphPlist = COItemGraphToJSONPropertyList(graph);
        
        [contentsForRevisionID setObject: @{ @"graph" : graphPlist, @"info" : revInfoPlist }
                                  forKey: [revid stringValue]];
    }
    
    return @{@"persistentRoot" : [persistentRoot stringValue],
             @"branches" : branches,
             @"currentBranchUUID" : [serverInfo.currentBranchUUID stringValue],
             @"revisions" : contentsForRevisionID,
             @"serverID" : aRequest[@"serverID"]};
}

@end
