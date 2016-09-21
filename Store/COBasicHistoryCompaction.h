/**
    Copyright (C) 2015 Quentin Mathe

    Date:  June 2015
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COHistoryCompaction.h>

/**
 * @group Store
 * @abstract A basic compaction strategy used by 
 * -[COSQLiteStore finalizeDeletionsForPersistentRoots:].
 *
 * This class is only exposed to be used internally by CoreObject.
 */
@interface COBasicHistoryCompaction : NSObject <COHistoryCompaction>
{
	@private
	NSSet *_finalizablePersistentRootUUIDs;
	NSSet *_compactablePersistentRootUUIDs;
	NSSet *_finalizableBranchUUIDs;
	NSSet *_compactableUUIDs;
}

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * See -[COHistoryCompaction finalizablePersistentRootUUIDs].
 */
@property (nonatomic, readwrite, copy) NSSet *finalizablePersistentRootUUIDs;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * See -[COHistoryCompaction compactablePersistentRootUUIDs].
 */
@property (nonatomic, readwrite, copy) NSSet *compactablePersistentRootUUIDs;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * See -[COHistoryCompaction finalizableBranchUUIDs].
 */
@property (nonatomic, readwrite, copy) NSSet *finalizableBranchUUIDs;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * See -[COHistoryCompaction compactableBranchUUIDs].
 */
@property (nonatomic, readwrite, copy) NSSet *compactableBranchUUIDs;

@end
