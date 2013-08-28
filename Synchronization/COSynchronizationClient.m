#import "COSynchronizationClient.h"


#import "COSQLiteStore.h"

@implementation COSynchronizationClient

/**
 * Make a request to send to the server
 */
- (NSDictionary *) updateRequestForPersistentRoot: (ETUUID *)aRoot
                                            store: (COSQLiteStore *)aStore
{
    COPersistentRootInfo *info = [aStore persistentRootInfoForUUID: aRoot];
    
    NSMutableDictionary *clientNewestRevisionIDForBranchUUID = [NSMutableDictionary dictionary];
    for (COBranchInfo *branch in [info branches])
    {
        [clientNewestRevisionIDForBranchUUID setObject: [[branch headRevisionID] plist]
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
