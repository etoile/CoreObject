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
@end


@interface COUndoTrackStore ()

- (BOOL) beginTransaction;
- (BOOL) commitTransaction;

- (NSArray *) trackNames;
- (NSArray *) trackNamesMatchingGlobPattern: (NSString *)aPattern;
- (COUndoTrackState *) stateForTrackName: (NSString*)aName;
- (void) setTrackState: (COUndoTrackState *)aState;
- (void) removeTrackWithName: (NSString*)aName;
- (NSArray *) allCommandUUIDsOnTrackWithName: (NSString*)aName;

/**
 * sequenceNumber is set in the provided command object
 */
- (void) addCommand: (COUndoTrackSerializedCommand *)aCommand;
- (COUndoTrackSerializedCommand *) commandForUUID: (ETUUID *)aUUID;
- (void) removeCommandForUUID: (ETUUID *)aUUID;

- (BOOL) string: (NSString *)aString matchesGlobPattern: (NSString *)aPattern;

@end
