/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "COStoreWriteRevision.h"
#import "COSQLiteStore+Private.h"

@implementation COStoreWriteRevision

@synthesize modifiedItems, revisionUUID, parentRevisionUUID, mergeParentRevisionUUID, persistentRoot, branch, schemaVersion, metadata;

- (BOOL)execute: (COSQLiteStore *)store inTransaction: (COStoreTransaction *)aTransaction
{
    return [store writeRevisionWithModifiedItems: modifiedItems
                                    revisionUUID: revisionUUID
                                        metadata: metadata
                                parentRevisionID: parentRevisionUUID
                           mergeParentRevisionID: mergeParentRevisionUUID
                              persistentRootUUID: persistentRoot
                                      branchUUID: branch
                                   schemaVersion: schemaVersion];
}

@end
