/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

/**
 * @group Object Collection and Organization
 *
 * CODictionary is a concrete class that exposes a NSDictionary-compatible API 
 * to support keyed collections in the CoreObject model. Dictionaries are not 
 * supported by the CoreObject serialization format.
 *
 * Both COObject and CODictionary are built on top of on COStoreItem, a 
 * low-level store representation for storing, diffing and merging entities 
 * and keyed collections.
 *
 * CODictionary is a mutable collection.
 */
@interface CODictionary : COObject <ETKeyedCollection, ETCollectionMutation>
{

}

/** @taskunit Keyed Collection Protocol */

- (NSArray *)allKeys;
- (NSArray *)allValues;
- (id)objectForKey: (id)aKey;
- (void)setObject: (id)anObject forKey: (id)aKey;
- (void)removeObjectForKey: (id)aKey;
- (void)removeAllObjects;

/** @taskunit Collection Protocol Additions */

/** Returns self. */
+ (Class) mutableClass;

@end
