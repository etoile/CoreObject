/*
	Copyright (C) 2012 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  January 2012
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COTrack.h>

@class COEditingContext;

/** 
 * @group History Navigation
 *
 * A persistent history track to aggregate hand-picked revisions produced by 
 * multiple unrelated objects.
 *
 * Unlike COHistoryTrack, COCustomTrack lets you control which revisions exist 
 * on the track, without worrying the objects that produced these revisions 
 * belong to the track. In other words, the tracked objects are lazily computed 
 * based on the revisions that were added to the track until now.
 *
 * COCustomTrack can be used to implement undo/redo track when the changes are 
 * not limited to a root object or root object collection (e.g. library), but 
 * span many objects edited in unrelated applications or concern actions that 
 * doesn't involve core objects.<br />
 * For example, an Object Manager that supports editing the entire CoreObject 
 * graph isn't interested in all the changes to support undo/redo at the 
 * application level, but only in the changes done in the ObjectManager. In this 
 * case, using COHistoryTrack wouldn't work, because most revisions produced by 
 * editing the objects in other applications have to be filtered out.
 */
@interface COCustomTrack : COTrack
{
	@private
	ETUUID *UUID;
	COEditingContext *editingContext;
	NSMutableArray *allNodes;
}

/** @taskunit Initialization */

/**
 * Returns a new autoreleased and persistent track bound to a UUID (rather than 
 * a particular object). 
 *
 * See also -initWithUUID:.
 */
+ (id)trackWithUUID: (ETUUID *)aUUID editingContext: (COEditingContext *)aContext;
/**
 * <init />
 * Initializes and returns a persistent track bound to a UUID (rather than a 
 * particular object).
 *
 * The UUID is used to persist this custom track at the store level, or retrieve 
 * its content when the track is recreated (if the same UUID is passed to the 
 * initializer more than one time).
 */
- (id)initWithUUID: (ETUUID *)aUUID editingContext: (COEditingContext *)aContext;
/**
 * Releases the receiver and returns nil.
 *
 * You must use -initWithUUID:editingContext:.
 */
- (id)initWithTrackedObjects: (NSSet *)objects;

/**
 * The UUID bound to the track.
 *
 * See also -initWithUUID: to know how to use the UUID to recreate the track.
 */
@property (readonly, nonatomic) ETUUID *UUID;
/**
 * The editing context targeted by -undo and -redo.
 */
@property (readonly, nonatomic) COEditingContext *editingContext;

/**
 * Appends new track nodes based on the revisions to the track timeline.
 *
 * See CORevision.
 */
- (void) addRevisions: (NSArray *)revisions;

@end
