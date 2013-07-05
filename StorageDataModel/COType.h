#import <Foundation/Foundation.h>

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

/**
 
 
 
 */
enum {
    kCOInt64Type = 1,
    kCODoubleType = 2,
    kCOStringType = 3,
    kCOBlobType = 4,
    kCOCommitUUIDType = 5,

    // Internal references (within a persistent root)
    kCOCompositeReferenceType = 7,
    kCOReferenceType = 9,
    
    // References across persistent roots
    kCOPathType = 6,
    
    
    kCOAttachmentType = 8,
    
    
    kCOSetType = 16,
    kCOArrayType = 32,
    
    kCOPrimitiveTypeMask = 0x0f,
    kCOMultivaluedTypeMask = 0xf0
};

static inline
BOOL COTypeIsMultivalued(COType type)
{
    return (type & kCOMultivaluedTypeMask) != 0;
}

static inline
BOOL COTypeIsPrimitive(COType type)
{
    return (type & kCOMultivaluedTypeMask) == 0;
}

static inline
BOOL COTypeIsOrdered(COType type)
{
    return (type & kCOMultivaluedTypeMask) == kCOArrayType;
}

static inline
COType COPrimitiveType(COType type)
{
    return type & kCOPrimitiveTypeMask;
}
