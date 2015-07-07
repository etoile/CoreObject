/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class COUndoTrack;
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
@property (nonatomic, readwrite, strong) NSDictionary *metadata;
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
@property (nonatomic, readwrite, assign) BOOL compacted;
@end

@interface COUndoTrackStore : NSObject
{
    FMDatabase *_db;
	NSMutableDictionary *_modifiedTrackStateForTrackName;
}

+ (COUndoTrackStore *) defaultStore;

/** @taskunit Framework Private */

- (BOOL) beginTransaction;
- (BOOL) commitTransaction;

- (NSArray *) trackNames;
- (NSArray *) trackNamesMatchingGlobPattern: (NSString *)aPattern;
- (COUndoTrackState *) stateForTrackName: (NSString*)aName;
- (void) setTrackState: (COUndoTrackState *)aState;
- (void) removeTrackWithName: (NSString*)aName;
/**
 * Returns UUIDs for all the commands on a given track.
 *
 * This doesn't include commands marked as deleted.
 *
 * See -markCommandsAsDeletedForUUIDs:.
 */
- (NSArray *) allCommandUUIDsOnTrackWithName: (NSString*)aName;

/**
 * sequenceNumber is set in the provided command object
 */
- (void) addCommand: (COUndoTrackSerializedCommand *)aCommand;
/**
 * Returns the serialized representation for the command bound to the given UUID.
 *
 * If the UUID corresponds to a deleted command, returns nil.
 */
- (COUndoTrackSerializedCommand *) commandForUUID: (ETUUID *)aUUID;
- (void) removeCommandForUUID: (ETUUID *)aUUID;


/** @taskunit History Compaction Integration */


/**
 * Marks the given commands as deleted.
 *
 * This should be called before compacting the history with COSQLiteStore.
 *
 * Posts a COUndoTrackStoreTrackDidChangeNotification with 
 * COUndoTrackStoreTrackCompacted set to YES.
 */
- (void)markCommandsAsDeletedForUUIDs: (NSArray *)UUIDs;
/**
 * Erases commands marked as deleted permanently.
 *
 * This should be called after compacting the history with COSQLiteStore.
 */
- (void)finalizeDeletions;


- (BOOL) string: (NSString *)aString matchesGlobPattern: (NSString *)aPattern;

@end
