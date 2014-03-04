/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import "COSQLiteStore.h"
#import "FMDatabase.h"

@class COSQLiteStorePersistentRootBackingStore;

/**
 * Private methods which are exposed so tests can look at the store internals.
 */
@interface COSQLiteStore ()

- (FMDatabase *) database;

- (ETUUID *) backingUUIDForPersistentRootUUID: (ETUUID *)aUUID;

- (BOOL) writeRevisionWithModifiedItems: (COItemGraph *)anItemTree
                           revisionUUID: (ETUUID *)aRevisionUUID
                               metadata: (NSDictionary *)metadata
                       parentRevisionID: (ETUUID *)aParent
                  mergeParentRevisionID: (ETUUID *)aMergeParent
                     persistentRootUUID: (ETUUID *)aUUID
                             branchUUID: (ETUUID*)branch;

- (COSQLiteStorePersistentRootBackingStore *) backingStoreForPersistentRootUUID: (ETUUID *)aUUID
															 createIfNotPresent: (BOOL)createIfNotPresent;


- (void) testingRunBlockInStoreQueue: (void (^)())aBlock;

@end
