/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2011
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

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

/** @taskunit Metamodel */

/**
 * <override-subclass />
 * Returns a persistent property that describes the collection content in a way 
 * that matches the superclass contraints.
 * 
 * The returned property can be customized, then inserted into the entity built 
 * with +newEntityDescription in your subclass.
 * 
 * Name and type must not be nil.
 *
 * Both type and opposite must be entity description names such as 
 * <em>Anonymous.NSObject</em> or <em>NSObject</em>.<br />
 * The <em>Anonymous</em> prefix is optional. Most entity description names 
 * don't require a prefix, because they don't belong to a package description 
 * but are just registered at runtime directly, and belong to this Anonymous 
 * package as a result.
 *
 * The default implementation raises an exception.
 */
+ (ETPropertyDescription *)contentPropertyDescriptionWithName: (NSString *)aName
                                                         type: (NSString *)aType
                                                     opposite: (NSString *)oppositeType;
/**
 * <override-never />
 * Returns UTI type for the collection elements.
 *
 * For inserting a new object in the collection, you can use this method to 
 * known the object class to instantiate. 
 *
 * The returned UTI depends on -[ETPropertyDescription type] for the content 
 * property description (looked up using -contentKey).<br />
 * To customize the type, you must edit the receiver entity description.
 *
 * See also -[ETController currentObjectType] in EtoileUI.
 */
- (ETUTI *)objectType;
/**
 * <override-never />
 * Returns whether the collection is ordered.
 *
 * The returned value is controlled by -[ETPropertyDescription isOrdered] for 
 * the content property description (looked up using -contentKey).
 */
- (BOOL) isOrdered;

/** @taskunit Content Access */

/**
 * <override-dummy />
 * Returns the property name that holds the collection content.
 *
 * This method is used by COCollection to implement 
 * ETCollection and ETCollectionMutation protocol methods. Subclasses must 
 * thereby return a valid key, other the collection API won't behave correctly.
 *
 * For example, -insertObject:atIndex:hint: implementation uses the content key 
 * to invoke -[COObject insertObject:atIndex:hint:forProperty:].
 *
 * By default, returns <em>contents</em>.
 */
- (NSString *)contentKey;

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
