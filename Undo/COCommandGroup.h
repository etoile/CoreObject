/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COCommand.h>

@class COCommitDescriptor;
@class COUndoTrackSerializedCommand;

/**
 * @group Undo
 * @abstract A command group represents a commit done in an editing context
 *
 * See COCommand for a detailed presentation.
 */
@interface COCommandGroup : NSObject <COTrackNode, ETCollection>
{
	@private
	COUndoTrack __weak *_parentUndoTrack;
	/**
	 * Not equal to _parentUndoTrack.name if _parentUndoTrack is a pattern track
	 */
	NSString *_trackName;
	NSMutableArray *_contents;
	NSDictionary *_metadata;
	ETUUID *_UUID;
	ETUUID *_parentUUID;
    NSDate *_timestamp;
	int64_t _sequenceNumber;
}

- (instancetype) initWithSerializedCommand: (COUndoTrackSerializedCommand *)aCommand
									 owner: (COUndoTrack *)anOwner;

- (COUndoTrackSerializedCommand *) serializedCommand;

/** @taskunit Basic Properties */

/**
 * The undo track on which the command was recorded.
 *
 * Never returns nil once the command has been recorded, see
 * -[COUndoTrack recordCommand:].
 */
@property (nonatomic, readwrite, weak) COUndoTrack *parentUndoTrack;
/**
 * The undo track name on which the command was recorded.
 */
@property (nonatomic, readwrite, strong) NSString *trackName;
/**
 * The commit UUID. 
 *
 * Allows an in-memory instance to be unambiguously mapped to a row in the SQL 
 * database behind COUndoTrack. Generated when the command is created, persists
 * across reads and writes to the database, but not preserved across calls to 
 * -inverse.
 */
@property (nonatomic, copy) ETUUID *UUID;
/**
 * The atomic commands grouped in the receiver for a commit. 
 *
 * Cannot contain COCommandGroup objects.
 */
@property (nonatomic, copy) NSMutableArray *contents;
/**
 * The commit metadata.
 */
@property (nonatomic, copy) NSDictionary *metadata;
/**
 * The commit descriptor matching the commit identifier in -metadata.
 *
 * COCommand overrides -localizedTypeDescription and -localizedShortDescription 
 * to return the equivalent commit descriptor descriptions.
 */
@property (nonatomic, readonly) COCommitDescriptor *commitDescriptor;
@property (nonatomic, readwrite) ETUUID *parentUUID;
/**
 * The commit time.
 */
@property (nonatomic, copy) NSDate *timestamp;
@property (nonatomic, readwrite) int64_t sequenceNumber;

- (COCommandGroup *) inverse;
- (void) applyToContext: (COEditingContext *)aContext;
- (void) addToStoreTransaction: (COStoreTransaction *)txn assumingEditingContextState: (COEditingContext *)ctx;

@end
