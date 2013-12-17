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
	CORevisionCache *cache = [cachesByStoreUUID objectForKey: [aStore UUID]];

	if (cache == nil)
	{
		[cachesByStoreUUID setObject: [[CORevisionCache alloc] initWithStore: aStore]
		                      forKey: [aStore UUID]];
	}
}

- (id) initWithStore: (COSQLiteStore *)aStore
{
    SUPERINIT;
	_store = aStore;
    _revisionForRevisionID = [[NSMutableDictionary alloc] init];
    return self;
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
