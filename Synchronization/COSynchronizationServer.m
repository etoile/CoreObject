#import "COSynchronizationServer.h"

#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSynchronizationServer

static void SearchForRevisionsClientLacks(NSMutableSet *resultSet, CORevisionID *rev, NSSet *clientLatestRevisions, COSQLiteStore *store)
{
    if ([clientLatestRevisions containsObject: rev])
    {
        return;
    }
    
    [resultSet addObject: rev];
    
    // Recursively search the parent(s)
    
    CORevisionInfo *info = [store revisionInfoForRevisionID: rev];
    if ([info parentRevisionID] != nil)
    {
        SearchForRevisionsClientLacks(resultSet, [info parentRevisionID], clientLatestRevisions, store);
    }
    if ([info mergeParentRevisionID] != nil)
    {
        SearchForRevisionsClientLacks(resultSet, [info mergeParentRevisionID], clientLatestRevisions, store);
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
        CORevisionID *revid = [aStore revisionIDForRevisionUUID: [ETUUID UUIDWithString: revisionUUIDString]
                                             persistentRootUUID: persistentRoot];

        [clientLatestRevisions addObject: revid];
    }
    
    // 2. Calculate the set of CORevisionID that the client lacks
    NSMutableSet *revisionsClientLacks = [NSMutableSet set];
    for (COBranchInfo *branch in [serverInfo branches])
    {
        SearchForRevisionsClientLacks(revisionsClientLacks, [branch headRevisionID], clientLatestRevisions, aStore);
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
        branchPlist[@"headRevisionID"] = [[branch.headRevisionID revisionUUID] stringValue];
        branchPlist[@"tailRevisionID"] = [[branch.tailRevisionID revisionUUID] stringValue];
        branchPlist[@"currentRevisionID"] = [[branch.currentRevisionID revisionUUID] stringValue];
        if (branch.metadata != nil)
        {
            branchPlist[@"metadata"] = branch.metadata;
        }
        
        [branches setObject: branchPlist
                     forKey: [[branch UUID] stringValue]];
    }
    
    NSMutableDictionary *contentsForRevisionID = [NSMutableDictionary dictionary];
    for (CORevisionID *revid in revisionsClientLacks)
    {
        id<COItemGraph> graph = [aStore itemGraphForRevisionID: revid];
        CORevisionInfo *revInfo = [aStore revisionInfoForRevisionID: revid];
        
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
        
        id graphPlist = COItemGraphToJSONPropertyList(graph);
        
        [contentsForRevisionID setObject: @{ @"graph" : graphPlist, @"info" : revInfoPlist }
                                  forKey: [[revid revisionUUID] stringValue]];
    }
    
    return @{@"persistentRoot" : [persistentRoot stringValue],
             @"branches" : branches,
             @"revisions" : contentsForRevisionID,
             @"serverID" : aRequest[@"serverID"]};
}

@end
