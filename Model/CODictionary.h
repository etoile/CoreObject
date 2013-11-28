/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COItem.h>

/**
 * @group Object Serialization
 *
 * CODictionarySerialization is a category to support persistent keyed 
 * properties in the CoreObject model. Dictionaries are not supported natively 
 * by the CoreObject serialization format.
 *
 * Both COObject and dictionary persistency are built on top of on COItem, a 
 * low-level store representation for storing, diffing and merging records. 
 *
 * A record is a unordered collection that contains attribute-value pairs,  
 * representing either an entity or a dictionary in CoreObject.
 */
@interface COObject (CODictionarySerialization)

/** @taskunit Serialization Additions */

- (COItem *)storeItemFromDictionaryForPropertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (NSDictionary *)dictionaryFromStoreItem: (COItem *)anItem
                   forPropertyDescription: (ETPropertyDescription *)aPropertyDesc;

@end

/**
 * @group Object Serialization
 *
 * Additions to store item to support dictionary serialization.
 */
@interface COItem (CODictionarySerialization)
/**
 * Returns YES when the item doesn't represent an entity object in the 
 * object graph context, but just a property attached to some COObject instance.
 */
- (BOOL)isAdditionalItem;
@end
