/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import "CORevisionCache.h"
#import "CORevision.h"
#import "COSQLiteStore.h"

@implementation CORevisionCache

@synthesize store = _store;

/**
 * N.B.: The values are unsafe retained
 */
static NSMapTable *cachesByStoreUUID = nil;

+ (void)initialize
{
	if (self != [CORevisionCache class])
		return;

	cachesByStoreUUID = [NSMapTable mapTableWithStrongToWeakObjects];
}

+ (id) cacheForStoreUUID: (ETUUID *)aUUID
{
	return [cachesByStoreUUID objectForKey: aUUID];
}

- (void) dealloc
{
	[cachesByStoreUUID removeObjectForKey: _storeUUID];
}

- (id) initWithStore: (COSQLiteStore *)aStore
{
	NILARG_EXCEPTION_TEST(aStore);
	
	CORevisionCache *cache = [cachesByStoreUUID objectForKey: [aStore UUID]];
	if (cache != nil)
	{
		return cache;
	}
	
    SUPERINIT;
	_store = aStore;
    _revisionForRevisionID = [[NSMutableDictionary alloc] init];
	_storeUUID = [aStore UUID];
	[cachesByStoreUUID setObject: self
						  forKey: _storeUUID];
    return self;
}

- (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid
					  persistentRootUUID: (ETUUID *)aPersistentRoot
{
    CORevision *cached = [_revisionForRevisionID objectForKey: aRevid];
    if (cached == nil)
    {
		ETAssert([self store] != nil);
        CORevisionInfo *info = [[self store] revisionInfoForRevisionUUID: aRevid
													  persistentRootUUID: aPersistentRoot];
        
		if (info == nil)
			return nil;

        cached = [[CORevision alloc] initWithCache: self revisionInfo: info];
        
        [_revisionForRevisionID setObject: cached forKey: aRevid];
    }
    return cached;
}

+ (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid
					  persistentRootUUID: (ETUUID *)aPersistentRoot
							   storeUUID: (ETUUID *)aStoreUUID
{
    return [[self cacheForStoreUUID: aStoreUUID] revisionForRevisionUUID: aRevid
													  persistentRootUUID: aPersistentRoot];
}

@end
