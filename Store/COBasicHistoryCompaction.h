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
	NSMutableSet *_deadPersistentRootUUIDs;
	NSMutableSet *_livePersistentRootUUIDs;
}

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * See -[COHistoryCompaction deadPersistentRootUUIDs].
 */
@property (nonatomic, readwrite) NSSet *deadPersistentRootUUIDs;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * See -[COHistoryCompaction livePersistentRootUUIDs].
 */
@property (nonatomic, readwrite) NSSet *livePersistentRootUUIDs;

@end
