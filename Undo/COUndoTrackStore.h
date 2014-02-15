/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  August 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class COUndoTrack;
@class FMDatabase;
@class ETUUID;

@interface COUndoTrackSerializedCommand : NSObject
@property (readwrite, nonatomic) id JSONData;
@property (readwrite, nonatomic) NSDictionary *metadata;
@property (readwrite, nonatomic) ETUUID *UUID;
@property (readwrite, nonatomic) ETUUID *parentUUID;
@property (readwrite, nonatomic) NSString *trackName;
@property (readwrite, nonatomic) NSDate *timestamp;
@property (readwrite, nonatomic) int64_t sequenceNumber;
@end

@interface COUndoTrackState : NSObject
@property (readwrite, nonatomic) NSString *trackName;
@property (readwrite, nonatomic) ETUUID *headCommandUUID;
@property (readwrite, nonatomic) ETUUID *currentCommandUUID;
@end

@interface COUndoTrackStore : NSObject
{
    FMDatabase *_db;
}

+ (COUndoTrackStore *) defaultStore;

/** @taskunit Framework Private */

- (BOOL) beginTransaction;
- (BOOL) commitTransaction;

- (NSArray *) trackNames;
- (COUndoTrackState *) stateForTrackName: (NSString*)aName;
- (void) setTrackState: (COUndoTrackState *)aState;
- (void) removeTrackWithName: (NSString*)aName;

/**
 * sequenceNumber is set in the provided command object
 */
- (void) addCommand: (COUndoTrackSerializedCommand *)aCommand;
- (COUndoTrackSerializedCommand *) commandForUUID: (ETUUID *)aUUID;
- (void) removeCommandForUUID: (ETUUID *)aUUID;

@end
