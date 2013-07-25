/*
	Copyright (C) 2013 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COType.h>

@class COItem;

extern NSString *kCOObjectEntityNameProperty;

@interface COObject (COSerialization)

/**
 * The receiver serialized representation.
 *
 * -storeItem is used to serialize a COObject state and -setStoreItem: to 
 * deserialize a COObject state. COObjectGraphContext will call these accessors
 * respectively at commit and loading times.
 *
 * At the end of -setStoreItem: -awakeFromDeserialization is called to recreate 
 * additional internal state based on the deserialization result. You must not
 * touch and attempt to access or recreated relationships during
 * -awakeFromDeserialization. For relationship restoration, you can implement
 * -didLoadObjectGraph. 
 *
 * -storeItem is also useful to inspect the serialized representation that goes
 * into the store.
 */
@property (nonatomic, copy) COItem *storeItem;

/** @taskunit Serialization */

- (id)serializedValueForValue: (id)aValue;
- (id)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc value: (id)value;

/** @taskunit Deserialization */

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
          propertyDescription: (ETPropertyDescription *)aPropertyDesc;

/** @taskunit Testing */

/**
 * Serializes the property value into the CoreObject serialized representation,
 * then unserialize it back into a value that can be passed
 * -setSerializedValue:forPropertyDescription:.
 *
 * The property value is retrieved with -serializedValueForPropertyDescription:, 
 * serialized using -serializedValueForValue: and deserialized using
 * -valueForSerializedValue:ofType:propertyDescription:.
 */
- (id)roundTripValueForProperty: (NSString *)key;

@end
