/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>
#import <CoreObject/COTrack.h>

@class COEditingContext, COUndoTrack, COStoreTransaction;

NS_ASSUME_NONNULL_BEGIN

/**
 * @group Undo
 * @abstract A command represents a committed change in an editing context
 *
 * For each store change operation (e.g. branch creation, new revision etc.), 
 * there is a distinct command in the COCommand class hierarchy.
 *
 * A commit is not atomic, if it spans several persistent roots. Non-atomic 
 * commits are represented as a COCommandGroup that contains one or more command 
 * objects to describe each store structure change independently.<br />
 * If you make multiple store structure changes on a single persistent root 
 * (e.g. branch creation and new revision at the same time), the command group 
 * is going to contain several commands just for a single persistent root.
 */
@interface COCommand : NSObject <COTrackNode>
{
    COUndoTrack __weak *_parentUndoTrack;
    ETUUID *_storeUUID;
    ETUUID *_persistentRootUUID;
}


/** @taskunit Basic Properties */


/**
 * <override-subclass />
 * A localized string describing the command.
 *
 * For example, -[COCommandDeletePersistentRoot kind] returns <em>Persistent 
 * Root Deletion</em>.
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
 * The UUID of the store against which the changes were or would be committed
 * (for an inverse).
 */
@property (nonatomic, readwrite, copy) ETUUID *storeUUID;
/**
 * The UUID of the persistent root to which the changes were or would be applied
 * (for an inverse).
 */
@property (nonatomic, readwrite, copy) ETUUID *persistentRootUUID;
/**
 * Returns nil.
 *
 * An atomic command belongs to a command group which has a parent command.
 */
@property (nonatomic, readonly, nullable) id <COTrackNode> parentNode;
/**
 * Returns nil.
 */
@property (nonatomic, readonly, nullable) id <COTrackNode> mergeParentNode;


/** @taskunit Applying and Reverting Changes */


/**
 * <override-subclass />
 * Returns a command that represents an inverse action.
 *
 * You can use the inverse to unapply the receiver changes in an editing context.
 *
 * <code>[[command inverse] inverse]</code> must be equal 
 * <code>[command inverse]</code>.
 *
 * A single command corresponds to an atomic operation inside a commit
 * (e.g. just a branch creation or just a new revision).
 *
 * For each commit, single commands are grouped into a COCommandGroup.
 */
@property (nonatomic, readonly) COCommand *inverse;

// FIXME: Perhaps distinguish between edits that can't be applied and edits that
// are already applied. (e.g. "create branch", but that branch already exists)

/** 
 * <override-subclass />
 * Returns whether the receiver changes can be applied to the editing context.
 */
- (BOOL)canApplyToContext: (COEditingContext *)aContext;
/**
 * <override-subclass />
 * Applies the receiver changes to the editing context.
 */
- (void)applyToContext: (COEditingContext *)aContext;
/**
 * <override-subclass />
 * Applies the receiver changes directly to a store transaction.
 */
- (void)addToStoreTransaction: (COStoreTransaction *)txn
         withRevisionMetadata: (nullable NSDictionary<NSString *, id> *)metadata
  assumingEditingContextState: (COEditingContext *)ctx;


/** @taskunit Framework Private */


/**
 * <override-never />
 * Returns a command deserialized from a property list.
 *
 * See -initWithPropertyList:parentUndoTrack:.
 */
+ (COCommand *)commandWithPropertyList: (id)aPlist parentUndoTrack: (COUndoTrack *)aParent;
/**
 * <init />
 * Initializes and returns a command deserialized from a property list.
 */
- (instancetype)initWithPropertyList: (id)plist
                     parentUndoTrack: (COUndoTrack *)aParent NS_DESIGNATED_INITIALIZER;
/**
 * <init />
 * Returns a command that needs to be initialized manually.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 * Returns the receiver serialized as a property list.
 */
@property (nonatomic, readonly, strong) id propertyList;

/**
 * Returns a new command equal to the receiver.
 */
- (id)copyWithZone: (NSZone *)zone;

@end

NS_ASSUME_NONNULL_END

