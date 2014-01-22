/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

@class COSQLiteStore, CORevision;


@interface CORevisionCache : NSObject
{
	@private
    COSQLiteStore * __weak _store;
    NSMutableDictionary *_revisionForRevisionID;
	ETUUID *_storeUUID;
}

/** @taskunit Revision Access */

/**
 * Look up the requested revision in the cache. Returns nil if the revision is
 * not found.
 */
+ (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid
					  persistentRootUUID: (ETUUID *)aPersistentRoot
							   storeUUID: (ETUUID *)aStoreUUID;

/** @taskunit Subclassing */


- (id) initWithStore: (COSQLiteStore *)aStore;
- (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid
					  persistentRootUUID: (ETUUID *)aPersistentRoot;

@property (nonatomic, readonly, weak) COSQLiteStore *store;


/** @taskunit Framework Private */

// TODO: Don't expose. It is a cache implementation detail.
+ (id)cacheForStoreUUID: (ETUUID *)aUUID;

@end
