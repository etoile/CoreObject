/**	<title>ETHistory</title>

	<abstract>A generic history class which can contain arbitary entries located 
	in the past or the future.</abstract>

	Copyright (C) 2008 Truls Becken <truls.becken@gmail.com>

	Date:  December 2008
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETCollection.h>

/**
 * ETHistory keeps a history of objects of some kind. After going back
 * in time, it can go forward again towards the most recent object. Adding an
 * object while at a historic point will discard the forward history.
 *
 * It is also possible to give the manager an NSEnumerator to use as a lazy
 * source for the forward history. This way, a collection of objects can be
 * added as a "future", replacing the current forward history.
 *
 * ETHistory supports ETCollection protocol, but not ETCollectionMutation 
 * which means -isMutableCollection returns NO and an history won't considered 
 * as a mutable represented object by EtoileUI.
 **/
@interface ETHistory : NSObject <ETCollection>
{
	NSMutableArray *history;
	NSEnumerator *future;
	int max_size;
	int index;
}

/**
 * Return a new autoreleased history manager.
 */
+ (id) history;
/**
 * <init />Initialize the history manager.
 */
- (id) init;
/**
 * Set new current object, discarding the forward history.
 */
- (void) addObject: (id)object;
/**
 * Return the current object.
 */
- (id) currentObject;
/**
 * Go one step back if possible.
 */
- (void) back;
/**
 * Go back, and return the new current object or nil if already at the start.
 */
- (id) previousObject;
/**
 * Return YES if it is possible to go back.
 */
- (BOOL) hasPrevious;
/**
 * After going back, call this to go one step forward again.
 */
- (void) forward;
/**
 * Go forward, and return the new current object or nil if already at the end.
 */
- (id) nextObject;
/**
 * Return YES if it is possible to go forward.
 */
- (BOOL) hasNext;
/**
 * Return an object at a position relative to the current object. Return nil if
 * the index refers to a point before the beginning or after the end of time.
 */
- (id) peek: (int)relativeIndex;
/**
 * Forget the history and discard the future.
 */
- (void) clear;
/**
 * Set an enumerator to use as the forward history, discarding everything after
 * the current object.
 */
- (void) setFuture: (NSEnumerator *)enumerator;
/**
 * Set the maximum number of objects to remember. When more objects than this
 * are added, the oldest ones are forgotten.
 *
 * The default is to remember an unlimited number of objects (max size = 0).
 *
 * Note that max size only limits the number of objects before currentObject.
 * Setting a future and peeking into it may force the history manager to
 * temporarily hold more objects.
 */
- (void) setMaxHistorySize: (int)maxSize;
/**
 * Return the maximum number of objects to remember.
 */
- (int) maxHistorySize;
/**
 * Return 'History'.
 *
 * See also -[NSObject(Model) displayName].
 */
- (NSString *) displayName;
/**
 * Returns YES.
 */
- (BOOL) isOrdered;
/**
 * See -isEmpty in ETCollection protocol.
 */
- (BOOL) isEmpty;
/**
 * See -content in ETCollection protocol.
 */
- (id) content;
/**
 * See -contentArray in ETCollection protocol.
 */
- (NSArray *) contentArray;

@end
