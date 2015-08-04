/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

@class COUndoTrack;
@class FMDatabase;
@class ETUUID;

/**
 * @group Undo
 * @abstract A specialized store to persist undo tracks.
 *
 * @section Conceptual Model
 *
 * If you intend to share a CoreObject store with multiple applications, the 
 * default undo track store should be used, otherwise it's usually better to
 * use an undo track store that remains private to your application.
 *
 * With a private undo track store, the history can be backed up and compacted 
 * without worrying about other applications.
 *
 * With the default undo track store, you cannot replace the database on disk 
 * at run-time and reload the instance returned by +[COUndoTrackStore defaultStore], 
 * since other applications can be using it.
 *
 * @section Current Limitations
 *
 * For now, COUndoTrackStore doesn't post distributed notifications, so undo 
 * tracks have no way to observe multiple instances of the same store 
 * (COUndoTrackStore objects initialized with the same URL). This means 
 * COUndoTrack will only track changes posted by the undo track store instance
 * of their editing context.
 *
 * For the default undo track store, all CoreObject applications must link
 * CoreObject versions whose COUndoTrackStore schema versions are identical.
 */
@interface COUndoTrackStore : NSObject
{
	@private
	NSURL *_URL;
    FMDatabase *_db;
	NSMutableDictionary *_modifiedTrackStateForTrackName;
	dispatch_queue_t _queue;
	dispatch_semaphore_t _transactionLock;
}


/** @taskunit Initialization */

/**
 * Returns the default store that can shared by CoreObject applications.
 *
 * This store is backed by a single database on disk per user account.
 */
+ (instancetype)defaultStore;
/**
 * <init />
 * Returns a new store backed by the database located at the given URL.
 *
 * If there is no database at the given URL, a new one is created, otherwise 
 * the existing one is reused.
 *
 * For a nil argument or a URL which doesn't referenced the local filesystem,
 * raises a NSInvalidArgumentException.
 */
- (instancetype)initWithURL: (NSURL *)aURL;


/** @taskunit Basic Properties */


/**
 * The database URL.
 *
 * See also -initWithURL:.
 */
@property (nonatomic, readonly) NSURL *URL;

@end
