/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

@class COEditingContext, CORevision;


@interface CORevisionCache : NSObject
{
	@private
    COEditingContext __weak *_parentContext;
    NSMutableDictionary *_revisionForRevisionID;
}

/** @taskunit Framework Private */

@property (nonatomic, readonly, weak) COEditingContext *parentEditingContext;

- (id) initWithParentEditingContext: (COEditingContext *)aCtx;
- (CORevision *) revisionForRevisionUUID: (ETUUID *)aRevid
					  persistentRootUUID: (ETUUID *)aPersistentRoot;

@end
