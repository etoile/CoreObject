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

static NSMutableDictionary *cachesByStoreUUID = nil;

+ (void)initialize
{
	if (self != [CORevisionCache class])
		return;

	cachesByStoreUUID = [NSMutableDictionary new];
}

+ (id)cacheForStoreUUID: (ETUUID *)aUUID
{
	return [cachesByStoreUUID objectForKey: aUUID];
}

+ (void) prepareCacheForStore: (COSQLiteStore *)aStore
{
	NILARG_EXCEPTION_TEST(aStore);
	CORevisionCache *cache = [cachesByStoreUUID objectForKey: [aStore UUID]];

	if (cache == nil)
	{
		cache = [[CORevisionCache alloc] initWithStore: aStore];

		[cachesByStoreUUID setObject: cache
		                      forKey: [aStore UUID]];
	}
	[cache retainFromClient];
}

+ (void) discardCacheForStore: (COSQLiteStore *)aStore
{
	NILARG_EXCEPTION_TEST(aStore);
	CORevisionCache *cache = [cachesByStoreUUID objectForKey: [aStore UUID]];
	ETAssert(cache != nil);

	BOOL discard = [cache releaseFromClient];

	if (discard)
	{
		[cachesByStoreUUID removeObjectForKey: [aStore UUID]];
	}
}

- (id) initWithStore: (COSQLiteStore *)aStore
{
    SUPERINIT;
	_store = aStore;
    _revisionForRevisionID = [[NSMutableDictionary alloc] init];
	_clientCount = 0;
    return self;
}

- (void)retainFromClient
{
	_clientCount++;
}

- (BOOL)releaseFromClient
{
	ETAssert(_clientCount > 0);
	_clientCount--;
	
	return (_clientCount == 0);
}

- (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid
					  persistentRootUUID: (ETUUID *)aPersistentRoot
{
    CORevision *cached = [_revisionForRevisionID objectForKey: aRevid];
    if (cached == nil)
    {
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
