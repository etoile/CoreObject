#import "CORelationshipCache.h"
#import <EtoileFoundation/ETUUID.h>
#import <EtoileFoundation/Macros.h>
#import "COType.h"
#import "COItem.h"

@implementation CORelationshipRecord

@synthesize uuid = uuid_;
@synthesize property = property_;

+ (CORelationshipRecord *) recordWithUUID: (ETUUID *)aUUID property: (NSString *)aProp
{
    CORelationshipRecord *result = [[[self alloc] init] autorelease];
    result.uuid = aUUID;
    result.property = aProp;
    return result;
}

- (void) dealloc
{
    [uuid_ release];
    [property_ release];
    [super dealloc];
}

- (NSUInteger)hash
{
    // TODO: Benchmark, access UUID bytes directly via a pointer?
    return *(NSUInteger *)([uuid_ UUIDValue]);
}

- (BOOL)isEqual:(id)object
{
    // TODO: Benchmark, access UUID bytes directly via a pointer?
	CORelationshipRecord *other = object;
    return [property_ isEqualToString: other->property_]
        && (0 == memcmp([uuid_ UUIDValue], [other->uuid_ UUIDValue], 16));
}

@end

@implementation CORelationshipCache

#define INITIAL_DICTIONARY_CAPACITY 256
#define INITIAL_SET_CAPACITY 8

- (id) init
{
    SUPERINIT;
    referrerUUIDsForUUID_ = [[NSMutableDictionary alloc] initWithCapacity: INITIAL_DICTIONARY_CAPACITY];
    embeddedObjectParentUUIDForUUID_ = [[NSMutableDictionary alloc] initWithCapacity: INITIAL_DICTIONARY_CAPACITY];
    tempRecord_ = [[CORelationshipRecord alloc] init];
    return self;
}

- (void) dealloc
{
    [referrerUUIDsForUUID_ release];
    [embeddedObjectParentUUIDForUUID_ release];
    [tempRecord_ release];
    [super dealloc];
}

- (CORelationshipRecord *) parentForUUID: (ETUUID *)anObject
{
    return [embeddedObjectParentUUIDForUUID_ objectForKey: anObject];
}

- (void) setParentUUID: (ETUUID *)aParent
               forUUID: (ETUUID*)anObject
           forProperty: (NSString *)aProperty
{
    CORelationshipRecord *record = [[CORelationshipRecord alloc] init];
    record.uuid = aParent;
    record.property = aProperty;
    [embeddedObjectParentUUIDForUUID_ setObject: record forKey: anObject];
    [record release];
}

- (void) clearParentForUUID: (ETUUID*)anObject
{
    [embeddedObjectParentUUIDForUUID_ removeObjectForKey: anObject];
}

- (void) addReferrerUUID: (ETUUID *)aReferrer
                 forUUID: (ETUUID*)anObject
             forProperty: (NSString *)aProperty
{
    NSMutableSet *set = [referrerUUIDsForUUID_ objectForKey: anObject];
    if (set == nil)
    {
        set = [[NSMutableSet alloc] initWithCapacity: INITIAL_SET_CAPACITY];
        [referrerUUIDsForUUID_ setObject: set forKey: anObject];
        [set release];
    }
    
    CORelationshipRecord *record = [[CORelationshipRecord alloc] init];
    record.uuid = aReferrer;
    record.property = aProperty;
    [set addObject: record];
    [record release];
}

- (void) removeReferrerUUID: (ETUUID *)aReferrer
                    forUUID: (ETUUID*)anObject
                forProperty: (NSString *)aProperty
{
    tempRecord_.uuid = aReferrer;
    tempRecord_.property = aProperty;
    [(NSMutableSet *)[referrerUUIDsForUUID_ objectForKey: anObject] removeObject: tempRecord_];
}

- (NSSet *) referrersForUUID: (ETUUID *)anObject
{
    return [referrerUUIDsForUUID_ objectForKey: anObject];
}

- (NSSet *) referrersForUUID: (ETUUID *)anObject
            propertyInParent: (NSString*)propInParent
{
    NSMutableSet *results = [NSMutableSet set];
    NSSet *all = [referrerUUIDsForUUID_ objectForKey: anObject];
    
    for (CORelationshipRecord *record in all)
    {
        if ([record.property isEqualToString: propInParent])
        {
            [results addObject: record.uuid];
        }
    }
    return results;
}

- (void) clearOldValue: (id)oldVal
               oldType: (COType)oldType
           forProperty: (NSString *)aProperty
              ofObject: (ETUUID *)anObject
{
    if (oldVal != nil)
    {
        if (COPrimitiveType(oldType) == kCOCompositeReferenceType)
        {
            if (COTypeIsMultivalued(oldType))
            {
                for (id obj in oldVal)
                {
                    [self clearParentForUUID: obj];
                }
            }
            else
            {
                [self clearParentForUUID: oldVal];
            }
        }
        else if (COPrimitiveType(oldType) == kCOReferenceType)
        {
            if (COTypeIsMultivalued(oldType))
            {
                for (id obj in oldVal)
                {
                    [self removeReferrerUUID: anObject forUUID: obj forProperty: aProperty];
                }
            }
            else
            {
                [self removeReferrerUUID: anObject forUUID: oldVal forProperty: aProperty];
            }
        }
    }
}

- (void) setNewValue: (id)newVal
             newType: (COType)newType
         forProperty: (NSString *)aProperty
            ofObject: (ETUUID *)anObject
{
    if (newVal != nil)
    {
        if (COPrimitiveType(newType) == kCOCompositeReferenceType)
        {
            if (COTypeIsMultivalued(newType))
            {
                for (id obj in newVal)
                {
                    [self setParentUUID: anObject forUUID: obj forProperty: aProperty];
                }
            }
            else
            {
                [self setParentUUID: anObject forUUID: newVal forProperty: aProperty];
            }
        }
        else if (COPrimitiveType(newType) == kCOReferenceType)
        {
            if (COTypeIsMultivalued(newType))
            {
                for (id obj in newVal)
                {
                    [self addReferrerUUID: anObject forUUID: obj forProperty: aProperty];
                }
            }
            else
            {
                [self addReferrerUUID: anObject forUUID: newVal forProperty: aProperty];
            }
        }
    }
}

- (void) updateRelationshipCacheWithOldValue: (id)oldVal
                                     oldType: (COType)oldType
                                    newValue: (id)newVal
                                     newType: (COType)newType
                                 forProperty: (NSString *)aProperty
                                    ofObject: (ETUUID *)anObject
{
    [self clearOldValue: oldVal
                oldType: oldType
            forProperty: aProperty
               ofObject: anObject];
    
    [self setNewValue: newVal
              newType: newType
          forProperty: aProperty
             ofObject: anObject];
}

- (void) addItem: (COItem *)anItem
{
    ETUUID *uuid = [anItem UUID];
    for (NSString *key in [anItem attributeNames])
    {
        [self setNewValue: [anItem valueForAttribute: key]
                  newType: [anItem typeForAttribute: key]
              forProperty: key
                 ofObject: uuid];
    }
}

- (void) removeItem: (COItem *)anItem
{
    ETUUID *uuid = [anItem UUID];
    for (NSString *key in [anItem attributeNames])
    {
        [self clearOldValue: [anItem valueForAttribute: key]
                    oldType: [anItem typeForAttribute: key]
                forProperty: key
                   ofObject: uuid];
    }
    // N.B. We don't unset the parent of anItem.
    // That data is conceptually owned by the parent, and will be unset when/if the parent is removed
}

- (void) removeAllEntries
{
    [embeddedObjectParentUUIDForUUID_ removeAllObjects];
    [referrerUUIDsForUUID_ removeAllObjects];
}

@end
