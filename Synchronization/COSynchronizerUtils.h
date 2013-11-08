#import <CoreObject/CoreObject.h>

@interface COSynchronizerUtils : NSObject

/**
 * Rebases the topic branch "source" onto the master branch "dest".
 * Conflicts are automatically resolved, favouring the topic branch.
 *
 * The revisions must be already committed.
 *
 * Returns an array of the new revision UUIDs.
 */
+ (NSArray *) rebaseRevision: (ETUUID *)source
				ontoRevision: (ETUUID *)dest
		  persistentRootUUID: (ETUUID *)persistentRoot
				  branchUUID: (ETUUID *)branch
					   store: (COSQLiteStore *)store
				 transaction: (COStoreTransaction *)txn;

@end
