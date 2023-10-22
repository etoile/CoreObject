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

- (instancetype)initWithStore:(COSQLiteStore *)aStore
{
    NILARG_EXCEPTION_TEST(aStore);
    SUPERINIT;
    _store = aStore;
    _revisionForRevisionID = [[NSMutableDictionary alloc] init];
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (instancetype)init
{
    return [self initWithStore: nil];
}

#pragma clang diagnostic pop

- (CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid
                     persistentRootUUID: (ETUUID *)aPersistentRoot
{
    CORevision *cached = _revisionForRevisionID[aRevid];

    if (cached == nil)
    {
        ETAssert(_store != nil);
        CORevisionInfo *info = [_store revisionInfoForRevisionUUID: aRevid
                                                persistentRootUUID: aPersistentRoot];

        if (info == nil)
            return nil;

        cached = [[CORevision alloc] initWithCache: self revisionInfo: info];
        _revisionForRevisionID[aRevid] = cached;
    }
    return cached;
}

@end
