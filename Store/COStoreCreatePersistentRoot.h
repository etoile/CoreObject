/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Creates an empty persistent root (with no branches).
 * If persistentRootForCopy is set, shares a backing store with that persistent
 * root, otherwise, creates a new backing store.
 */
@interface COStoreCreatePersistentRoot : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite, nullable) ETUUID *persistentRootForCopy;

@end

NS_ASSUME_NONNULL_END
