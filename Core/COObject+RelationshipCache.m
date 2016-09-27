/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  July 2013
    License:  MIT  (see COPYING)
 */

#import "COObject+RelationshipCache.h"
#import "COObject+Private.h"
#import "CORelationshipCache.h"
#import "COObjectGraphContext.h"
#import "COEditingContext+Private.h"
#import "COCrossPersistentRootDeadRelationshipCache.h"
#import "COPath.h"
#import "COPrimitiveCollection.h"

@implementation COObject (RelationshipCache)

static inline BOOL isPersistentCoreObjectReferencePropertyDescription(ETPropertyDescription *prop)
{
    // NOTE: For now, we don't support keyed relationships, and we don't want to
    // interpret a CODictionary as a relationship, when we use it as a
    // multivalued collection.
    return prop.isPersistentRelationship && !prop.keyed;
}

- (void)removeCachedOutgoingRelationshipsForCollectionValue: (id)obj
                                  ofPropertyWithDescription: (ETPropertyDescription *)aProperty
{
    if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
    {
        COCrossPersistentRootDeadRelationshipCache *deadRelationshipCache =
            self.editingContext.deadRelationshipCache;


        BOOL isDeadReference = [obj isKindOfClass: [COPath class]];

        if (isDeadReference)
        {
            [deadRelationshipCache removeReferringObject: self
                                                 forPath: obj];
        }
        else
        {
            if (![obj isKindOfClass: [COObject class]])
            {
                // After inserting an illegal type of object into a collection that fails validation
                // (throwing an exception), we don't currently remove the invalid object.
                // (see -testNullDisallowedInCollection in the test suite.)
                // This is a hack so that -[COObjectGraphContext dealloc] can complete
                // without throwing an exception below, because the invalid object doesn't respond
                // to -incomingRelationshipCache.
                NSLog(@"%@ - note - ignoring non-COObject instance %@ in %@ of %@",
                      NSStringFromSelector(_cmd), obj, aProperty.name, self);
                return;
            }

            [[obj incomingRelationshipCache] removeReferencesForPropertyInSource: aProperty.name
                                                                    sourceObject: self];
        }
    }
}

- (void)removeCachedOutgoingRelationshipsForValue: (id)aValue
                        ofPropertyWithDescription: (ETPropertyDescription *)aProperty
{
    if (aValue != nil)
    {
        if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
        {
            if (aProperty.multivalued)
            {
                for (id obj in [aValue enumerableReferences])
                {
                    [self removeCachedOutgoingRelationshipsForCollectionValue: obj
                                                    ofPropertyWithDescription: aProperty];
                }
            }
            else
            {
                [self removeCachedOutgoingRelationshipsForCollectionValue: aValue
                                                ofPropertyWithDescription: aProperty];
            }
        }
    }
}

- (void)addCachedOutgoingRelationshipsForCollectionValue: (id)obj
                               ofPropertyWithDescription: (ETPropertyDescription *)aProperty
{
    ETAssert(obj != nil);

    if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
    {
        COCrossPersistentRootDeadRelationshipCache *deadRelationshipCache =
            self.editingContext.deadRelationshipCache;
        ETPropertyDescription *propertyInTarget = aProperty.opposite; // May be nil

        // Metamodel sanity check
        ETAssert(!aProperty.derived);
        if (propertyInTarget != nil)
        {
            NSAssert2(propertyInTarget.derived,
                      @"Your metamodel is invalid - the property %@ (opposite of %@) should be marked as derived.",
                      propertyInTarget.fullName,
                      aProperty.fullName);
            ETAssert(!propertyInTarget.persistent);
        }

        BOOL isDeadReference = [obj isKindOfClass: [COPath class]];

        if (isDeadReference)
        {
            [deadRelationshipCache addReferringObject: self
                                              forPath: obj];
        }
        else
        {
            [[obj incomingRelationshipCache] addReferenceFromSourceObject: self
                                                           sourceProperty: aProperty.name
                                                           targetProperty: propertyInTarget.name];
        }
    }

}

- (void)addCachedOutgoingRelationshipsForValue: (id)aValue
                     ofPropertyWithDescription: (ETPropertyDescription *)aProperty
{
    if (aValue != nil)
    {
        if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
        {
            ETPropertyDescription *propertyInTarget = aProperty.opposite; // May be nil

            // Metamodel sanity check
            ETAssert(!aProperty.derived);
            if (propertyInTarget != nil)
            {
                NSAssert2(propertyInTarget.derived,
                          @"Your metamodel is invalid - the property %@ (opposite of %@) should be marked as derived.",
                          propertyInTarget.fullName,
                          aProperty.fullName);
                ETAssert(!propertyInTarget.persistent);
            }

            if (aProperty.multivalued)
            {
                for (id obj in [aValue enumerableReferences])
                {
                    [self addCachedOutgoingRelationshipsForCollectionValue: obj
                                                 ofPropertyWithDescription: aProperty];
                }
            }
            else
            {
                [self addCachedOutgoingRelationshipsForCollectionValue: aValue
                                             ofPropertyWithDescription: aProperty];
            }
        }
    }
}

- (void)updateCachedOutgoingRelationshipsForOldValue: (id)oldVal
                                            newValue: (id)newVal
                           ofPropertyWithDescription: (ETPropertyDescription *)aProperty
{
    if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
    {
        [self removeCachedOutgoingRelationshipsForValue: oldVal
                              ofPropertyWithDescription: aProperty];
        [self addCachedOutgoingRelationshipsForValue: newVal
                           ofPropertyWithDescription: aProperty];
    }
}

- (void)removeCachedOutgoingRelationships
{
    for (ETPropertyDescription *prop in self.entityDescription.propertyDescriptions)
    {
        if (isPersistentCoreObjectReferencePropertyDescription(prop))
        {
            id value = [self valueForStorageKey: prop.name shouldLoad: NO];

            [self removeCachedOutgoingRelationshipsForValue: value
                                  ofPropertyWithDescription: prop];
        }
    }
}

@end
