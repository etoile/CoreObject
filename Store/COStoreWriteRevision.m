#import "COStoreWriteRevision.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreWriteRevision

@synthesize modifiedItems, revisionUUID, parentRevisionUUID, mergeParentRevisionUUID, persistentRoot, branch, metadata;

- (BOOL) execute: (COSQLiteStore *)store
{
    return [store writeRevisionWithModifiedItems: modifiedItems
                                    revisionUUID: revisionUUID
                                        metadata: metadata
                                parentRevisionID: parentRevisionUUID
                           mergeParentRevisionID: mergeParentRevisionUUID
                              persistentRootUUID: persistentRoot
                                      branchUUID: branch];
}

@end
