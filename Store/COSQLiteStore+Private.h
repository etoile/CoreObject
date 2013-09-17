#import "COSQLiteStore.h"
#import "FMDatabase.h"

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

@end