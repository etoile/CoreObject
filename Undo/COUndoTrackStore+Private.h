/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class FMDatabase;
@class ETUUID;

NSString * const COUndoTrackStoreTrackDidChangeNotification;

// User info keys for COUndoTrackStoreTrackDidChangeNotification
NSString * const COUndoTrackStoreTrackName;
/**
 * UUID string
 */
NSString * const COUndoTrackStoreTrackHeadCommandUUID;
/**
 * NSNull or UUID string
 */
NSString * const COUndoTrackStoreTrackCurrentCommandUUID;
/**
 * NSNumber boolean
 */
NSString * const COUndoTrackStoreTrackCompacted;

@interface COUndoTrackSerializedCommand : NSObject
@property (nonatomic, readwrite, strong) id JSONData;
@property (nonatomic, readwrite, copy) NSDictionary *metadata;
@property (nonatomic, readwrite, copy) ETUUID *UUID;
@property (nonatomic, readwrite, copy) ETUUID *parentUUID;
@property (nonatomic, readwrite, copy) NSString *trackName;
@property (nonatomic, readwrite, copy) NSDate *timestamp;
@property (nonatomic, readwrite, assign) int64_t sequenceNumber;
@end

@interface COUndoTrackState : NSObject <NSCopying>
@property (nonatomic, readwrite, copy) NSString *trackName;
@property (nonatomic, readwrite, copy) ETUUID *headCommandUUID;
@property (nonatomic, readwrite, copy) ETUUID *currentCommandUUID;
/** 
 * Reports whether a history compaction is underway for this track.
 *
 * For a cleaner API, we could replace 'compacted' by 'tailCommandUUID' to 
 * report compaction, but this is much more complex to implement.
 *
 * For state objects returned by -[COUndoTrackStore stateForTrackName:], this 
 * property is currently always NO.
 */
@property (nonatomic, readwrite, assign, getter=isCompacted) BOOL compacted;
@end


/**
 * COUndoTrackStore API is mostly thread-safe, except -beginTransaction,
 * -commitTransaction and -setTrackState: which must be run in the main thread.
 */
@interface COUndoTrackStore ()


/** @taskunit Initialization */


/**
 * Clears all content in memory and on disk, then resets the store schema.
 *
 * This is an alternative to deleting the database file on disk.
 *
 * See also -[COSQLiteStore clearStore].
 */
- (void) clearStore;


/** @taskunit Batch Operations */


/**
 * Begins a COUndoTrackStore transaction to run multiple COUndoTrackStore
 * API operations.
 *
 * Returns whether initiating the transaction has succeeded.
 *
 * This method must be run in the main thread.
 */
- (BOOL)beginTransaction;
/**
 * Ends a COUndoTrackStore transaction previously initiated with 
 * -beginTransaction.
 *
 * Returns whether committing the transaction has succeeded.
 *
 * This method must be run in the main thread.
 */
- (BOOL)commitTransaction;


/** @taskunit Managing Undo Tracks */


/**
 * Returns the current track names.
 *
 * Once a track persistent state is saved with -setStateForTrackName:, the
 * track appears in the returned array until -removeTrackWithName: is called.
 */
@property (nonatomic, readonly) NSArray *trackNames;
/**
 * Returns the current track names that match a pattern built with '*'.
 *
 * To know how the matching works, see GLOB definition in SQLite documentation.
 *
 * See COPatternUndoTrack which uses this method to discover its child tracks.
 */
- (NSArray *) trackNamesMatchingGlobPattern: (NSString *)aPattern;
/**
 * Returns the persistent state describing a track.
 *
 * When no persistent state exists in the dabase, returns nil. This means the 
 * track has never saved or has been deleted.
 */
- (COUndoTrackState *) stateForTrackName: (NSString*)aName;
/**
 * Updates the persistent state describing a track.
 *
 * If the database contains no persistent state corresponding to this track, 
 * this acts a track insertion (-trackNames will include it once the method 
 * returns).
 *
 * This method must be run in the main thread.
 */
- (void) setTrackState: (COUndoTrackState *)aState;
/**
 * Deletes a track including all its commands.
 */
- (void) removeTrackWithName: (NSString*)aName;



/** @taskunit Managing Commands */


/**
 * Saves a command and sets -[COUndoTrackSerializedCommand sequenceNumber].
 */
- (void) addCommand: (COUndoTrackSerializedCommand *)aCommand;
/** 
 * Deletes the command bound the given UUID.
 */
- (void) removeCommandForUUID: (ETUUID *)aUUID;
/**
 * Returns the serialized representation for the command bound to the given UUID.
 *
 * If the UUID corresponds to a deleted command, returns nil.
 */
- (COUndoTrackSerializedCommand *) commandForUUID: (ETUUID *)aUUID;
/**
 * Returns UUIDs for all the commands on a given track.
 *
 * This doesn't include commands marked as deleted.
 *
 * See -markCommandsAsDeletedForUUIDs:.
 */
- (NSArray *) allCommandUUIDsOnTrackWithName: (NSString*)aName;



/** @taskunit History Compaction Integration */


/**
 * Marks the given commands as deleted.
 *
 * This should be called before compacting the history with COSQLiteStore.
 *
 * Posts a COUndoTrackStoreTrackDidChangeNotification with 
 * COUndoTrackStoreTrackCompacted set to YES.
 *
 * Can be run a the main queue or a background queue.
 *
 * To run it in the main queue, while a transaction initiated with 
 * -beginTransaction is underway will result in a deadlock.
 */
- (void)markCommandsAsDeletedForUUIDs: (NSArray *)UUIDs;
/**
 * Erases commands marked as deleted permanently.
 *
 * This should be called after compacting the history with COSQLiteStore.
 *
 * Can be run a the main queue or a background queue.
 *
 * To run it in the main queue, while a transaction initiated with
 * -beginTransaction is underway will result in a deadlock.
 */
- (void)finalizeDeletions;
/**
 * Compacts the database by rebuilding it.
 *
 * This shrinks the database file size unlike -finalizeDeletions.
 *
 * This operation is slow and will block the database until the method returns.
 *
 * Can be run a the main queue or a background queue.
 *
 * To run it in the main queue, while a transaction initiated with
 * -beginTransaction is underway will result in a deadlock.
 * 
 * See also -[COSQLiteStore vacuum].
 */
- (BOOL)vacuum;
/**
 * See -[COSQLiteStore pageStatistics].
 */
@property (nonatomic, readonly) NSDictionary *pageStatistics;


/** @task Glob Pattern Matching */


/**
 * Returns whether the given string would be matched by this SQLite glob pattern.
 *
 * See also -trackNamesMatchingGlobPattern:.
 */
- (BOOL) string: (NSString *)aString matchesGlobPattern: (NSString *)aPattern;

@end
