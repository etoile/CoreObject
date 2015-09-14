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
@interface COCommandGroup : NSObject <COTrackNode, ETCollection, NSCopying>
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


/** @taskunit Basic Properties */


/**
 * A localized string describing the command.
 */
@property (nonatomic, readonly) NSString *kind;
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
/**
 * The UUID of the parent command. 
 *
 * The parent command is the command upon on this one is based, it is not 
 * necessarily the previous command by -sequenceNumber.
 *
 * An Undo track can contain divergences that look like "branches" in the Undo 
 * history. After an undo, any new commit makes the Undo track diverges. At 
 * this point, the last undo and the previously created commands that follow it, 
 * don't appear in the Undo track unless divergent commands are explicitly shown.
 *
 * Before compaction, the first command in a track is always a non-persistent
 * COEndOfUndoTrackPlaceholderNode instance; its parent UUID is nil. The first 
 * persistent divergent commands in a track have a parent UUID equal to
 * [[COEndOfUndoTrackPlaceholderNode sharedInstance] UUID].
 *
 * After compaction, the first command in a track is never a
 * COEndOfUndoTrackPlaceholderNode instance; its parent UUID  corresponds to a 
 * deleted command.
 *
 * See also -[COUndoTrack childrenOfNode:].
 */
@property (nonatomic, readwrite) ETUUID *parentUUID;
/**
 * The commit time.
 */
@property (nonatomic, copy) NSDate *timestamp;
/**
 * The commit order in the Undo track store.
 */
@property (nonatomic, readwrite) int64_t sequenceNumber;
/**
 * The parent command, see -parentUUID.
 *
 * Returns [COEndOfUndoTrackPlaceholderNode sharedInstance] for the first 
 * recorded COCommandGroup(s) on a track.
 */
@property (nonatomic, readonly) id <COTrackNode> parentNode;
/**
 * Returns nil.
 */
@property (nonatomic, readonly) id <COTrackNode> mergeParentNode;


/** @taskunit Applying and Reverting Changes */


/**
 * Returns a command that represents an inverse action.
 *
 * You can use the inverse to unapply the receiver changes in an editing context.
 *
 * <code>[[command inverse] inverse]</code> must be equal 
 * <code>[command inverse]</code>.
 */
- (COCommandGroup *) inverse;
/** 
 * Returns whether the receiver changes can be applied to the editing context.
 */
- (BOOL) canApplyToContext: (COEditingContext *)aContext;
/**
 * Applies the receiver changes to the editing context.
 */
- (void) applyToContext: (COEditingContext *)aContext;
/**
 * Applies the receiver changes directly to a store transaction.
 */
- (void) addToStoreTransaction: (COStoreTransaction *)txn
		  withRevisionMetadata: (NSDictionary *)metadata
   assumingEditingContextState: (COEditingContext *)ctx;


/** @taskunit Framework Private */


/**
 * <init />
 * Initializes a command group from a serialized represention and with a parent 
 * undo track.
 */
- (instancetype) initWithSerializedCommand: (COUndoTrackSerializedCommand *)aCommand
									 owner: (COUndoTrack *)anOwner;
/**
 * Returns a serialized represention.
 */
- (COUndoTrackSerializedCommand *) serializedCommand;

@end
