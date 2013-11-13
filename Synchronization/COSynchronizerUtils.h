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

/**
 * Doesn't set merge parent. Parent of written revision is branch2.
 */
+ (ETUUID *) writeMergeWithBaseRevision: (ETUUID *)source
							firstBranch: (ETUUID *)branch1
						   secondBranch: (ETUUID *)branch2
					 persistentRootUUID: (ETUUID *)persistentRoot
							 branchUUID: (ETUUID *)branch
								  store: (COSQLiteStore *)store
							transaction: (COStoreTransaction *)txn;


@end
