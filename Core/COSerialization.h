/**
	Copyright (C) 2013 Quentin Mathe, Eric Wasylishen

	Date:  July 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>
#import <CoreObject/COType.h>

@class COItem;

extern NSString *kCOObjectEntityNameProperty;
extern NSString *kCOObjectIsSharedProperty;

/**
 * @group Core
 * @abstract Additions to convert inner objects into a "semi-serialized" 
 * representation.
 *
 * COObjectGraphContext uses -storeItem to serialize a COObject into a COItem,  
 * and -setStoreItem: to deserialize in the reverse way.
 *
 * For debugging a serialization/deserialization cycle, see 
 * -roundTripValueForProperty:.
 *
 * NOTE: The rest of the API is unstable and incomplete.
 */
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

/** @taskunit Querying Serialization Types */

- (BOOL) isSerializablePrimitiveValue: (id)value;
- (BOOL) isSerializableScalarValue: (id)value;

/** @taskunit Serialization */

- (id)serializedValueForValue: (id)aValue;
- (id)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc value: (id)value;
- (SEL)serializationGetterForProperty: (NSString *)property;
- (COItem *)storeItemWithUUID: (ETUUID *)aUUID
                        types: (NSMutableDictionary *)types
                       values: (NSMutableDictionary *)values
                   entityName: (NSString *)anEntityName;
- (COItem *)additionalStoreItemForUUID: (ETUUID *)anItemUUID;

/** @taskunit Deserialization */

- (id)valueForSerializedValue: (id)value
                       ofType: (COType)type
          propertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (SEL)serializationSetterForProperty: (NSString *)property;
- (void)validateStoreItem: (COItem *)aStoreItem;

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
