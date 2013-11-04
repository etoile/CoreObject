#import "COSynchronizationServer.h"

#import <CoreObject/CoreObject.h>
#import "CORevisionCache.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COSynchronizationServer

static void FindAllParents(NSMutableSet *resultSet, ETUUID *rev, ETUUID *persistentRootUUID, COSQLiteStore *store, NSSet *stopSet)
{
    if ([resultSet containsObject: rev])
        return;

    if (stopSet != nil && [stopSet containsObject: rev])
		return;
	
    [resultSet addObject: rev];
    
    // Recursively search the parent(s)
    
    CORevision *revision = [CORevisionCache revisionForRevisionUUID: rev persistentRootUUID: persistentRootUUID storeUUID: [store UUID]];
	
    if ([revision parentRevision] != nil)
    {
        FindAllParents(resultSet, [[revision parentRevision] UUID], persistentRootUUID, store, stopSet);
    }
    if ([revision mergeParentRevision] != nil)
    {
        FindAllParents(resultSet, [[revision mergeParentRevision] UUID], persistentRootUUID, store, stopSet);
    }
}

- (BOOL) shouldSendBranch: (COBranchInfo *)branch
{
	if (branch.metadata[@"source"] != nil)
	{
		return NO;
	}
	return YES;
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
    
	// 1. Calculate the set of revision ETUUID the client has
    NSMutableSet *revisionsClientHas = [NSMutableSet set];
    for (NSString *revisionUUIDString in [[aRequest objectForKey: @"clientNewestRevisionIDForBranchUUID"] allValues])
    {
        ETUUID *revid = [ETUUID UUIDWithString: revisionUUIDString];

		FindAllParents(revisionsClientHas, revid, persistentRoot, aStore, nil);
    }
    
    // 2. Calculate the set of CORevisionID that the client lacks
    NSMutableSet *revisionsClientLacks = [NSMutableSet set];
    for (COBranchInfo *branch in [serverInfo branches])
    {
		if ([self shouldSendBranch: branch])
		{
			FindAllParents(revisionsClientLacks, [branch currentRevisionUUID], persistentRoot, aStore, revisionsClientHas);
		}
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
        branchPlist[@"initialRevisionID"] = [branch.initialRevisionUUID stringValue];
        branchPlist[@"currentRevisionID"] = [branch.currentRevisionUUID stringValue];
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
        if (revInfo.parentRevisionUUID != nil)
        {
            revInfoPlist[@"parent"] = [revInfo.parentRevisionUUID stringValue];
        }
        if (revInfo.mergeParentRevisionUUID != nil)
        {
            revInfoPlist[@"mergeParent"] = [revInfo.mergeParentRevisionUUID stringValue];
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
