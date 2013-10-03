/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  September 2013
	License:  Modified BSD  (see COPYING)
 */

#import "CORevisionCache.h"
#import "CORevision.h"
#import "CORevisionID.h"
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

- (CORevision *) revisionForRevisionID: (CORevisionID *)aRevid
{
    CORevision *cached = [_revisionForRevisionID objectForKey: aRevid];
    if (cached == nil)
    {
        CORevisionInfo *info = [[self store] revisionInfoForRevisionID: aRevid];
        
        cached = [[CORevision alloc] initWithCache: self revisionInfo: info];
        
        [_revisionForRevisionID setObject: cached forKey: aRevid];
    }
    return cached;
}

+ (CORevision *) revisionForRevisionID: (CORevisionID *)aRevid storeUUID: (ETUUID *)aStoreUUID
{
    return [[self cacheForStoreUUID: aStoreUUID] revisionForRevisionID: aRevid];
}

@end
