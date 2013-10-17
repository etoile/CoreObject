/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  July 2013
	License:  Modified BSD  (see COPYING)
 */

#import "COObject+RelationshipCache.h"
#import "COObject.h"
#import "COObject+Private.h"
#import "CORelationshipCache.h"
#import "COObjectGraphContext.h"
#import "COEditingContext.h"
#import "COCrossPersistentRootReferenceCache.h"
#import "COPath.h"

@implementation COObject (RelationshipCache)

// FIXME: Copied from COSerialization
static BOOL isCoreObjectEntityType(ETEntityDescription *aType)
{
	ETEntityDescription *type = aType;
	// TODO: Determine more directly
	do
	{
		if ([[type name] isEqualToString: @"COObject"])
			return YES;
        
		type = [type parent];
	}
	while (type != nil);
    
	return NO;
}

static BOOL isPersistentCoreObjectReferencePropertyDescription(ETPropertyDescription *prop)
{
    return [prop isPersistent] && isCoreObjectEntityType([prop type]);
}

- (void) removeCachedOutgoingRelationshipsForValue: (id)aValue
                         ofPropertyWithDescription: (ETPropertyDescription *)aProperty
{
    if (aValue != nil)
    {
        if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
        {
            if ([aProperty isMultivalued])
            {
                for (COObject *obj in aValue)
                {
                    [[obj incomingRelationshipCache] removeReferencesForPropertyInSource: [aProperty name]
                                                                    sourceObject: self];
                }
            }
            else
            {
                [[(COObject *)aValue incomingRelationshipCache] removeReferencesForPropertyInSource: [aProperty name]
                                                                               sourceObject: self];
            }
            
            // Update the cross-persistent root reference cache
            
            [[self crossReferenceCache] clearReferencedPersistentRootsForObject: self];
        }
    }
}

- (void) addCachedOutgoingRelationshipsForValue: (id)aValue
                      ofPropertyWithDescription: (ETPropertyDescription *)aProperty

{
    if (aValue != nil)
    {
        if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
        {
            ETPropertyDescription *propertyInTarget = [aProperty opposite];
            if (propertyInTarget != nil)
            {
                if ([aProperty isMultivalued])
                {
                    for (COObject *obj in aValue)
                    {
                        [[obj incomingRelationshipCache] addReferenceFromSourceObject: self
                                                               sourceProperty: [aProperty name]
                                                               targetProperty: [propertyInTarget name]];
                    }
                }
                else
                {
                    [[(COObject *)aValue incomingRelationshipCache] addReferenceFromSourceObject: self
                                                                          sourceProperty: [aProperty name]
                                                                          targetProperty: [propertyInTarget name]];
                }
            }
            
            // Update the cross-persistent root reference cache
            
            id relationshipAsCOPathOrETUUID = [_outgoingSerializedRelationshipCache objectForKey: [aProperty name]];
            if ([aProperty isMultivalued])
            {
                for (id refObject in relationshipAsCOPathOrETUUID)
                {
                    if ([refObject isKindOfClass: [COPath class]])
                    {
                        [[self crossReferenceCache] addReferencedPersistentRoot: [(COPath *)refObject persistentRoot]
                                                                      forObject: self];
                    }
                }
            }
            else
            {
                if ([relationshipAsCOPathOrETUUID isKindOfClass: [COPath class]])
                {
                    [[self crossReferenceCache] addReferencedPersistentRoot: [(COPath *)relationshipAsCOPathOrETUUID persistentRoot]
                                                                  forObject: self];
                }
            }
        }
    }
}

- (void) updateCachedOutgoingRelationshipsForOldValue: (id)oldVal
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

- (void) addCachedOutgoingRelationships
{
    for (ETPropertyDescription *prop in [[self entityDescription] propertyDescriptions])
    {
        if (isPersistentCoreObjectReferencePropertyDescription(prop))
        {
            id value = [self valueForKey: [prop name]];
            
            [self addCachedOutgoingRelationshipsForValue: value
                               ofPropertyWithDescription: prop];
        }
    }
}

- (void) removeCachedOutgoingRelationships
{
    for (ETPropertyDescription *prop in [[self entityDescription] propertyDescriptions])
    {
        if (isPersistentCoreObjectReferencePropertyDescription(prop))
        {
            id value = [self valueForKey: [prop name]];
            
            [self removeCachedOutgoingRelationshipsForValue: value
                                  ofPropertyWithDescription: prop];
        }
    }
}

@end
