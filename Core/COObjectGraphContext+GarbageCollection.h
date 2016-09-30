/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  October 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObjectGraphContext.h>

NS_ASSUME_NONNULL_BEGIN

@interface COObjectGraphContext (COGarbageCollection)

/**
 * Returns the subset of -itemUUIDs that are reachable from <code>self.rootObject</code>.
 *
 * Reachable means there is a chain of inner object references starting at the
 * root object (doesn't matter if the references are composite or not) that are
 * persistent (the property description returns YES from -isPersistent)
 *
 * Throws an exception if <code>self.rootObject</code> is nil.
 */
@property (nonatomic, readonly) NSSet<ETUUID *> *allReachableObjectUUIDs;

- (void)checkForCyclesInCompositeRelationshipsInChangedObjects;

@end

NS_ASSUME_NONNULL_END
