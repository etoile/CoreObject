#import <Foundation/Foundation.h>

/**
 * Each key/value pair of a COItem has a COType associated with it.
 *
 * The type defines the set of permissible values which can be set for
 * that attribute, and possibly additional semantics of the value
 * which aren't captured by the Objective-C object alone - for example,
 * one value in a COItem might be an NSArray instance, but the corresponding
 * COType might additionally indicate that the array contains inner item
 * UUIDs, and the array has a restriction that its elements must be unique.
 *
 * COType is designed with a few things in mind:
 *  - being able to store the values of a COItem in an SQL database,
 *    so the primitive types map cleanly to SQL types.
 *  - validation of ObjC objects against the schema
 *  - plist import/export of ObjC objects of a known COType
 */
typedef int32_t COType;

enum {
#pragma mark Primitive types
    
    /**
     * Represented as NSNumber
     */
    kCOTypeInt64 = 0x01,
    
    /**
     * Represented as NSNumber
     */
    kCOTypeDouble = 0x02,
    
    /**
     * Represented as NSString
     */
    kCOTypeString = 0x03,
    
    /**
     * A byte array. Represented as NSData
     */
    kCOTypeBlob = 0x04,

    /**
     * A reference that does not necessairily model parent-child relationships -
     * could be graphs with cycles, etc.
     *
     * Represented as COUUID for inner references and COPath for references
     * to other persistent roots.
     */
    kCOTypeReference = 0x05,
    
    /**
     * A composite reference from a parent to a child. The reference is stored
     * in the parent.
     *
     * N.B. this could be lumped together with kCOTypeReference and 
     * distinguished at the metamodel level only, but they are kept separate
     * to enhance support for loading data with no metamodel available, and ease
     * debugging.
     *
     * Represented as COUUID.
     */
    kCOTypeCompositeReference = 0x06,

    /**
     * A token which can be given to COSQLiteStore to retrieve a local 
     * filesystem path to an immutable attached file.
     *
     * Represented as NSData (a hash of the attached file's contents).
     */
    kCOTypeAttachment = 0x07,
   
#pragma mark Multivalued types
    
    /**
     * Represented as NSSet.
     */
    kCOTypeSet = 0x10,
    
    /**
     * Represented as NSArray
     */
    kCOTypeArray = 0x20,
    
    kCOTypePrimitiveMask = 0x0f,
    kCOTypeMultivaluedMask = 0xf0
};

static inline
COType COTypeMultivaluedPart(COType type)
{
    return type & kCOTypeMultivaluedMask;
}

static inline
COType COTypePrimitivePart(COType type)
{
    return type & kCOTypePrimitiveMask;
}

static inline
BOOL COTypeIsMultivalued(COType type)
{
    return COTypeMultivaluedPart(type) != 0;
}

static inline
BOOL COTypeIsPrimitive(COType type)
{
    return COTypeMultivaluedPart(type) == 0;
}

static inline
BOOL COTypeIsOrdered(COType type)
{
    return COTypeMultivaluedPart(type) == kCOTypeArray;
}

static inline
COType COTypeMakeSetOf(COType type)
{
    return type | kCOTypeSet;
}

static inline
COType COTypeMakeArrayOf(COType type)
{
    return type | kCOTypeArray;
}

static inline
BOOL COTypeIsValid(COType type)
{
    if (!(COTypePrimitivePart(type) >= kCOTypeInt64
          && COTypePrimitivePart(type) <= kCOTypeAttachment))
    {
        return NO;
    }
    
    if (!(COTypeMultivaluedPart(type) == 0
          || COTypeMultivaluedPart(type) == kCOTypeArray
          || COTypeMultivaluedPart(type) == kCOTypeSet))
    {
        return NO;
    }
    
    if (0 != (type & (~(kCOTypeMultivaluedMask | kCOTypePrimitiveMask))))
    {
        return NO;
    }
    
    return YES;
}

NSString *
COTypeDescription(COType type);

BOOL
COTypeValidateObject(COType type, id anObject);
