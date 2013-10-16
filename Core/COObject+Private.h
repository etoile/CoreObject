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

@class CORelationshipCache, COObjectGraphContext, COCrossPersistentRootReferenceCache;

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
 * COPersistentRoot uses this method to initialize a new object that was never 
 * committed.
 *
 * For a subclass, this method results in the subclass designated initializer 
 * being called.
 */
- (id)initWithUUID: (ETUUID *)aUUID 
 entityDescription: (ETEntityDescription *)anEntityDescription
objectGraphContext: (COObjectGraphContext *)aContext;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * COPersistentRoot uses this method to initialize a reloaded object that was 
 * previously committed.
 *
 * For a subclass, this method doesn't result in the subclass designated 
 * initializer being called.
 */
- (id)commonInitWithUUID: (ETUUID *)aUUID
       entityDescription: (ETEntityDescription *)anEntityDescription
      objectGraphContext: (COObjectGraphContext *)aContext
                   isNew: (BOOL)inserted;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (CORelationshipCache *)relationshipCache;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (COCrossPersistentRootReferenceCache *)crossReferenceCache;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (void) updateCrossPersistentRootReferences;
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

@end
