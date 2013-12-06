/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>, 
	         Quentin Mathe <quentin.mathe@gmail.com>
	Date:  October 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

@class CORelationshipCache, COObjectGraphContext;

@interface COObject ()

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns a new mutable dictionary to store properties.
 *
 * For multivalued properties not bound to an instance variable, the returned 
 * dictionary contains mutable collections that matches the metamodel.
 * 
 */
 - (NSMutableDictionary *)newVariableStorage;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Prepares an object to be initialized or deserialized.
 *
 * COObject initialization is broken in two steps:
 * 
 * <list>
 * <item>For a new object, prepare and initialize using the designated 
 * initializer (-initWithObjectGraphContext: or some other subclass designated 
 * initializer)</item>
 * <item>For loading an object, prepare and deserialize using -setStoreItem: 
 * (see -[COObjectGraphContext objectWithUUID:entityDescription:])</item>
 * </list>
 */
- (id)prepareWithUUID: (ETUUID *)aUUID
    entityDescription: (ETEntityDescription *)anEntityDescription
   objectGraphContext: (COObjectGraphContext *)aContext
                isNew: (BOOL)inserted  __attribute__((objc_method_family(init)));
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (NSDictionary *)additionalStoreItemUUIDs;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (CORelationshipCache *)incomingRelationshipCache;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void) markAsRemovedFromContext;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (id)valueForStorageKey: (NSString *)key;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void)setValue: (id)value forStorageKey: (NSString *)key;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Checks the collection to mutate, and the indexes that goes along, both 
 * respect the metamodel constraints.
 *
 * On success, returns the collection, otherwise raises an exception.
 */
- (id)collectionForProperty: (NSString *)key mutationIndexes: (NSIndexSet *)indexes;
/** 
 * This method is only exposed to be used internally by COObject e.g. 
 * -updateCompositeRelationshipForPropertyDescription: (don't use in subclasses).
 *
 * Checks the insertion and the object that goes along respect the metamodel 
 * constraints, then calls 
 * -willChangeValueForProperty:atIndexes:withObjects:mutationKind:, then 
 * -insertObjects:atIndexes:hints: on the collection 
 * bound to the property, and 
 * -didChangeValueForProperty:atIndexes:withObjects:mutationKind:.
 *
 * See also ETCollectionMutation. 
 */
- (void) insertObjects: (NSArray *)objects
             atIndexes: (NSIndexSet *)indexes
                 hints: (NSArray *)hints
           forProperty: (NSString *)key;
/** 
 * This method is only exposed to be used internally by COObject e.g. 
 * -updateCompositeRelationshipForPropertyDescription: (don't use in subclasses).
 *
 * Checks the removal and the object that goes along respect the metamodel 
 * constraints, then calls 
 * -willChangeValueForProperty:atIndexes:withObjects:mutationKind:, then 
 * -removeObjects:atIndexes:hints: on the collection 
 * bound to the property, and 
 * -didChangeValueForProperty:atIndexes:withObjects:mutationKind:.
 *
 * See also ETCollectionMutation. 
 */
- (void) removeObjects: (NSArray *)objects
             atIndexes: (NSIndexSet *)indexes
                 hints: (NSArray *)hints
           forProperty: (NSString *)key;
/**
 * This method is only exposed to be used in the CoreObject tests.
 */
- (NSSet *) referringObjects;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void) replaceReferencesToObjectIdenticalTo: (COObject *)anObject withObject: (COObject *)aReplacement;

@end
