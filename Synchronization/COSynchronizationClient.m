#import "COSynchronizationClient.h"


#import "COSQLiteStore.h"

@implementation COSynchronizationClient

/**
 * Make a request to send to the server
 */
- (NSDictionary *) updateRequestForPersistentRoot: (ETUUID *)aRoot
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
             @"persistentRoot" : [aRoot stringValue]};
}

- (void) handleUpdateResponse: (NSDictionary *)aResponse
                        store: (COSQLiteStore *)aStore
{
    ETUUID *persistentRoot = aResponse[@"persistentRoot"];
    
    
}

@end
