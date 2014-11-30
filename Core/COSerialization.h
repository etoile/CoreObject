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
 *
 * @section Persistent Properties
 *
 * For CoreObject, properties are either:
 *
 * <list>
 * <item>univalued attribute</item>
 * <item>multivalued attribute</item>
 * <item>univalued or to-one relationship</item>
 * <item>multivalued or to-many relationship</item>
 *
 * You use the metamodel to set a property as attribute/relationship with
 * -[ETPropertyDescription type], and as univalued/multivalued with 
 * -[ETPropertyDescription multivalued].
 *
 * Internally, these distinctions are mirrored in the storage data model, see 
 * COType.
 *
 * @section Univalued Persistent Types
 *
 *
 * COObject serialization supports the same univalued types than COItem (see
 * COType), plus some extra types such as NSDate or NSRect that it automatically
 * converts to a COType.
 *
 * For univalued properties, the supported persistent types are:
 *
 * <deflist>
 * <term>attachment</term><desc>COAttachmentID</desc>
 * <term>reference to an inner object or outer root object</term><desc>COObject</desc>
 * <term>string</term><desc>NSString</desc>
 * <term>data</term><desc>NSData</desc>
 * <term>integer</term><desc>NSNumber or C types whose value fits into an int64_t</desc>
 * <term>double</term>NSNumber or C types whose value fits into a double</desc>
 * <term>date</term><desc>NSDate (serialized as an int64_t using Java timestamp format)</desc>
 * <term>common scalar values</term><desc>CORect, COSize, COPoint, CORange</desc>
 * </deflist>
 *
 * For all univalued types, a null value is supported, it is equal to nil, 
 * except for numbers (zero is used in this role) and scalar values
 * (CONullRect, CONullPoint, CONullSize, CONullRange are used).
 *
 * Depending on the preprocessor flags and the compilation target 
 * (iOS, AppKit etc.), CoreObject scalar types are mapped to CoreGraphics types 
 * or AppKit types, but the storage representation remains the same in all
 * cases.
 */
@property (nonatomic, copy) COItem *storeItem;

/** @taskunit Querying Serialization Types */

- (BOOL) isSerializablePrimitiveValue: (id)value;
- (BOOL) isSerializableScalarValue: (id)value;

/** @taskunit Serialization */

- (id)serializedReferenceForObject: (COObject *)value;
- (id)serializedValueForValue: (id)aValue
          propertyDescription: (ETPropertyDescription *)aPropertyDesc;
- (id)serializedTypeForPropertyDescription: (ETPropertyDescription *)aPropertyDesc value: (id)value;
- (SEL)serializationGetterForProperty: (NSString *)property;
- (COItem *)storeItemWithUUID: (ETUUID *)aUUID
                        types: (NSMutableDictionary *)types
                       values: (NSMutableDictionary *)values
                   entityName: (NSString *)anEntityName;
- (COItem *)additionalStoreItemForUUID: (ETUUID *)anItemUUID;

/** @taskunit Deserialization */

- (COObject *)objectForSerializedReference: (id)value
									ofType: (COType)type
                       propertyDescription: (ETPropertyDescription *)aPropertyDesc;
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
 * serialized using -serializedValueForValue:propertyDescription: and 
 * deserialized using -valueForSerializedValue:ofType:propertyDescription:.
 */
- (id)roundTripValueForProperty: (NSString *)key;

@end
