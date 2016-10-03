/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import "CORevisionCache.h"
#import "CORevision.h"
#import "COEditingContext.h"

@implementation CORevisionCache

@synthesize parentEditingContext = _parentContext;

- (instancetype)initWithParentEditingContext: (COEditingContext *)aCtx
{
    NILARG_EXCEPTION_TEST(aCtx);
    SUPERINIT;
    _parentContext = aCtx;
    _revisionForRevisionID = [[NSMutableDictionary alloc] init];
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (instancetype)init
{
    return [self initWithParentEditingContext: nil];
}

#pragma clang diagnostic pop

- (CORevision *)revisionForRevisionUUID: (ETUUID *)aRevid
                     persistentRootUUID: (ETUUID *)aPersistentRoot
{
    ETAssert(_parentContext != nil);
    CORevision *cached = _revisionForRevisionID[aRevid];

    if (cached == nil)
    {
        COSQLiteStore *store = _parentContext.store;
        ETAssert(store != nil);
        CORevisionInfo *info = [store revisionInfoForRevisionUUID: aRevid
                                               persistentRootUUID: aPersistentRoot];

        if (info == nil)
            return nil;

        cached = [[CORevision alloc] initWithCache: self revisionInfo: info];
        _revisionForRevisionID[aRevid] = cached;
    }
    return cached;
}

@end
