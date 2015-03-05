/**
    Copyright (C) 2011 Eric Wasylishen

    Date:  December 2011
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COType.h>

@class ETUUID;

// TODO: Rename these variables to be prefixed by COItem and not COObject
extern NSString *kCOObjectEntityNameProperty;
extern NSString *kCOObjectVersionsProperty;
extern NSString *kCOObjectDomainsProperty;
extern NSString *kCOObjectIsSharedProperty;

/**
 * @group Storage Data Model
 * @abstract 
 * COItem is a "semi-serialized" representation of an inner object. 
 *
 * It is essentially just a strongly typed dictionary (See COType.h for the 
 * mapping between possible COType values and the corresponding permissible 
 * Objective-C classes). Note that COItem only contains "value" obects (or 
 * possibly, sets/arrays of value objects). So, for example, references to 
 * other inner objects are stored as ETUUID instances. 
 * 
 * COItem acts as an intermediate layer during serialization or deserialization -
 * the binary and JSON formats are both straightforward mappings of COItem to a 
 * byte stream.
 *
 * COItem helps decouple object graph concerns (which are handled by 
 * COObjectGraphContext) from the details of actual serialization (handled by 
 * COItem(Binary) and COItem(JSON), and COItem also defines the abstract storage 
 * model (independent of a particular serialization format like binary or JSON) 
 * that CoreObject uses. 
 */
@interface COItem : NSObject <NSCopying, NSMutableCopying>
{
    @package
	ETUUID *uuid;
    
    @protected
	NSMutableDictionary *types;
    NSMutableDictionary *values;
}


/** @taskunit Initialization */


/**
 * <init />
 */
- (id) initWithUUID: (ETUUID *)aUUID
 typesForAttributes: (NSDictionary *)typesForAttributes
valuesForAttributes: (NSDictionary *)valuesForAttributes;
+ (COItem *) itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
					valuesForAttributes: (NSDictionary *)valuesForAttributes;


/** @taskunit Accessing Attributes */


- (ETUUID *) UUID;
- (NSArray *) attributeNames;
- (COType) typeForAttribute: (NSString *)anAttribute;
- (id) valueForAttribute: (NSString*)anAttribute;


/** @taskunit Convenience */


/**
 * Returns the entity name corresponding to -[COObject entityDescription].
 */
@property (nonatomic, readonly) NSString *entityName;
@property (nonatomic, readonly) int64_t entityVersion;
@property (nonatomic, readonly) NSString *packageName;
/**
 * Returns the schema versions by package names.
 */
@property (nonatomic, readonly) NSDictionary *versionsByDomain;

// allows treating primitive or container, unordered or ordered as NSArray
- (NSArray*) allObjectsForAttribute: (NSString*)attribute;

- (NSSet *) compositeReferencedItemUUIDs;
- (NSSet *) referencedItemUUIDs;
- (NSSet *) allInnerReferencedItemUUIDs;

// GC helper methods
- (NSArray *) attachments;
- (NSArray *) allReferencedPersistentRootUUIDs;

- (NSString *) fullTextSearchContent;


/** @taskunit Copying */


- (id)copyWithZone:(NSZone *)zone;
- (id)mutableCopyWithZone:(NSZone *)zone;

/**
 * Returns a mutable item.
 */
- (id)mutableCopyWithNameMapping: (NSDictionary *)aMapping;

@end


/**
 * @group Storage Data Model
 * @abstract 
 * A mutable "semi-serialized" representation of an inner object.
 */
@interface COMutableItem : COItem
{
}


/** @taskunit Initialization */


- (id) initWithUUID: (ETUUID*)aUUID;
+ (COMutableItem *) itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
						   valuesForAttributes: (NSDictionary *)valuesForAttributes;
/**
 * Returns a new item with new UUID.
 */
+ (COMutableItem *) item;
+ (COMutableItem *) itemWithUUID: (ETUUID *)aUUID;


/** @taskunit Accessing Attributes */


- (void) setUUID: (ETUUID *)aUUID;
- (void) setValue: (id)aValue
	 forAttribute: (NSString*)anAttribute
			 type: (COType)aType;
- (void)removeValueForAttribute: (NSString*)anAttribute;


/** @taskunit Convenience */


@property (nonatomic, readwrite) NSString *entityName;
@property (nonatomic, readwrite) int64_t entityVersion;
@property (nonatomic, readwrite) NSString *packageName;

- (void) setValue: (id)aValue
	 forAttribute: (NSString*)anAttribute;

@end

