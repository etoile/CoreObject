#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>
#import "COType.h"

/**
 * This is a low-level model object which makes up the contents of a commit's
 * item tree. (a commit is a set of COItem plus the UUID of the root COItem.)
 *
 * It oversees import/export to/from plist format, delegating some of the work
 * to COType+Plist.
 *
 *
 * *NOTE*: COItem does not participate in an object graph with other COItem
 * objects; it's basically a "value" object. It can contain NSSet/NSDictionary/NSArray,
 * but these containers can only contain COUUID/NSData/NSNumber/NSString/COPath.
 *
 * See COSubtree for a higher-level model object, which uses COItem internally
 * but lets you manipulate a set of COItem's as the corresponding tree of ObjC objects, 
 * which is easier to work with than raw COItem (but they are exactly equivelant
 * in terms of the data they represent.)
 */
@interface COItem : NSObject <NSCopying, NSMutableCopying>
{
    @package
	ETUUID *uuid;
    
    @protected
	NSMutableDictionary *types;
    NSMutableDictionary *values;
    /**
     * I think this makes sense to store at the COItem level.
     * My hunch is we should store this here, but don't persist the 
     * schema names for individual properties.
     *
     */
    NSString *schemaName;
}

@property (nonatomic, readwrite, copy) NSString *schemaName;

/**
 * designated initializer.
 */
- (id) initWithUUID: (ETUUID *)aUUID
 typesForAttributes: (NSDictionary *)typesForAttributes
valuesForAttributes: (NSDictionary *)valuesForAttributes;

+ (COItem *) itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
					valuesForAttributes: (NSDictionary *)valuesForAttributes;

- (ETUUID *) UUID;

- (NSArray *) attributeNames;

- (COType) typeForAttribute: (NSString *)anAttribute;
- (id) valueForAttribute: (NSString*)anAttribute;

/** @taskunit convenience */

// allows treating primitive or container, unordered or ordered as NSArray
- (NSArray*) allObjectsForAttribute: (NSString*)attribute;

- (NSSet *) embeddedItemUUIDs;
- (NSSet *) referencedItemUUIDs;

// GC helper methods
- (NSArray *) attachments;
- (NSArray *) allReferencedPersistentRootUUIDs;

- (NSString *) fullTextSearchContent;

/** @taskunit NSCopying and NSMutableCopying */

- (id)copyWithZone:(NSZone *)zone;
- (id)mutableCopyWithZone:(NSZone *)zone;

/**
 * Returns a mutable item
 */
- (id)mutableCopyWithNameMapping: (NSDictionary *)aMapping;

@end



@interface COMutableItem : COItem
{
}

- (id) initWithUUID: (ETUUID*)aUUID;

+ (COMutableItem *) itemWithTypesForAttributes: (NSDictionary *)typesForAttributes
						   valuesForAttributes: (NSDictionary *)valuesForAttributes;
/**
 * new item with new UIID
 */
+ (COMutableItem *) item;
+ (COMutableItem *) itemWithUUID: (ETUUID *)aUUID;

- (void) setUUID: (ETUUID *)aUUID;

- (void) setValue: (id)aValue
	 forAttribute: (NSString*)anAttribute
			 type: (COType)aType;

- (void)removeValueForAttribute: (NSString*)anAttribute;

/**
 * Creates the container if needed.
 */
- (void)   addObject: (id)aValue
toUnorderedAttribute: (NSString*)anAttribute
				type: (COType)aType;

/**
 * Creates the container if needed.
 */
- (void)   addObject: (id)aValue
  toOrderedAttribute: (NSString*)anAttribute
			 atIndex: (NSUInteger)anIndex
				type: (COType)aType;


/** @taskunit convenience */

- (void) addObject: (id)aValue
	  forAttribute: (NSString*)anAttribute;

- (void) setValue: (id)aValue
	 forAttribute: (NSString*)anAttribute;

- (id) copyWithZone:(NSZone *)zone;

@end

