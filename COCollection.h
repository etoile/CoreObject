/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <ObjectMerging/COObject.h>

/**
 * @group Object Collection and Organization
 *
 * COCollection is a abstract class that provides a common API to various 
 * concrete collection subclasses such as COGroup or COContainer.
 *
 * COCollection represents a mutable collection, but subclasses can be immutable.
 */
@interface COCollection : COObject <ETCollection, ETCollectionMutation>
{

}

/** @taskunit Collection Mutation Additions */

/**
 * Adds all the given objects to the receiver content.
 */
- (void)addObjects: (NSArray *)anArray;
/**
 * Posts ETSourceDidUpdateNotification.
 *
 * You must invoke this method every time the collection is changed.
 * For example, when you override -insertObject:atIndex:hint:.
 *
 * EtoileUI relies on this notification to reload the UI transparently.
 */
- (void)didUpdate;

/** @taskunit Object Matching */

/**
 * Returns the first object whose identifier matches.
 *
 * The search is shallow, in other words limited to the objects in the receiver 
 * content.
 *
 * See -[COObject identifier].
 */
- (id)objectForIdentifier: (NSString *)anId;
/**
 * See -[COObjectMatching objectsMatchingQuery:].
 *
 * Object graph traversal implementation for COObjectMatching protocol.
 */
- (NSArray *)objectsMatchingQuery: (COQuery *)aQuery;

@end


/** @group Object Collection and Organization */
@interface COObject (COCollectionTypeQuerying)
/**
 * Returns whether the receiver is a group or not.
 */
- (BOOL)isGroup;
/**
 * Returns whether the receiver is a tag or not.
 *
 * A tag is group that belongs to -[COEditingContext tagGroup].
 */
- (BOOL)isTag;
/**
 * Returns whether the receiver is a container or not.
 */
- (BOOL)isContainer;
/**
 * Returns whether the receiver is a library or not.
 *
 * A library is a container.
 */
- (BOOL)isLibrary;
@end
