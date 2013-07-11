#import <Foundation/Foundation.h>

// TODO: Rename all symbols in this file to follow the patern COTypeXXX
// or kCOTypeXXX

/**
 * Each key/value pair of a COItem has a COType associated with it.
 *
 * The type defines the set of permissible values which can be set for
 * that attribute, and possibly additional semantics of the value
 * which aren't captured by the Objective-C object alone - for example,
 * one value in a COItem might be an NSArray instance, but the corresponding
 * COType might additionally indicate that the array contains embedded item
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
    kCOInt64Type = 0x01,
    
    /**
     * Represented as NSNumber
     */
    kCODoubleType = 0x02,
    
    /**
     * Represented as NSString
     */
    kCOStringType = 0x03,
    
    /**
     * A byte array. Represented as NSData
     */
    kCOBlobType = 0x04,

    /**
     * A reference that does not necessairily model parent-child relationships -
     * could be graphs with cycles, etc.
     *
     * Represented as COUUID for inner references and COPath for references
     * to other persistent roots.
     */
    kCOReferenceType = 0x05,
    
    /**
     * A composite reference from a parent to a child. The reference is stored
     * in the parent.
     *
     * N.B. this could be lumped together with kCOReferenceType and 
     * distinguished at the metamodel level only, but they are kept separate
     * to enhance support for loading data with no metamodel available, and ease
     * debugging.
     *
     * Represented as COUUID.
     */
    kCOCompositeReferenceType = 0x06,

    /**
     * A token which can be given to COSQLiteStore to retrieve a local 
     * filesystem path to an immutable attached file.
     *
     * Represented as NSData (a hash of the attached file's contents).
     */
    kCOAttachmentType = 0x07,
   
#pragma mark Multivalued types
    
    /**
     * Represented as NSSet.
     */
    kCOSetType = 0x10,
    
    /**
     * Represented as NSArray
     */
    kCOArrayType = 0x20,
    
    kCOPrimitiveTypeMask = 0x0f,
    kCOMultivaluedTypeMask = 0xf0
};

static inline
COType COMultivaluedType(COType type)
{
    return type & kCOMultivaluedTypeMask;
}

static inline
COType COPrimitiveType(COType type)
{
    return type & kCOPrimitiveTypeMask;
}

static inline
BOOL COTypeIsMultivalued(COType type)
{
    return COMultivaluedType(type) != 0;
}

static inline
BOOL COTypeIsPrimitive(COType type)
{
    return COMultivaluedType(type) == 0;
}

static inline
BOOL COTypeIsOrdered(COType type)
{
    return COMultivaluedType(type) == kCOArrayType;
}

static inline
COType COSetOfType(COType type)
{
    return type | kCOSetType;
}

static inline
COType COArrayOfType(COType type)
{
    return type | kCOArrayType;
}

static inline
BOOL COTypeIsValid(COType type)
{
    if (!(COPrimitiveType(type) >= kCOInt64Type
          && COPrimitiveType(type) <= kCOAttachmentType))
    {
        return NO;
    }
    
    if (!(COMultivaluedType(type) == 0
          || COMultivaluedType(type) == kCOArrayType
          || COMultivaluedType(type) == kCOSetType))
    {
        return NO;
    }
    
    if (0 != (type & (~(kCOMultivaluedTypeMask | kCOPrimitiveTypeMask))))
    {
        return NO;
    }
    
    return YES;
}
