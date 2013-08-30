#import "COSQLiteStore.h"

/**
 * Private methods which are exposed so tests can look at the store internals.
 */
@interface COSQLiteStore ()

- (ETUUID *) backingUUIDForPersistentRootUUID: (ETUUID *)aUUID;

@end