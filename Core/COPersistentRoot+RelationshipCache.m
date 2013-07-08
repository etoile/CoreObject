#import "COPersistentRoot+RelationshipCache.h"
#import "COObject.h"
#import "CORelationshipCache.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COPersistentRoot (RelationshipCache)

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
                                          ofObject: (COObject *)anObject
{
    if (aValue != nil)
    {
        if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
        {
            if ([aProperty isMultivalued])
            {
                for (COObject *obj in aValue)
                {
                    [[obj relationshipCache] removeReferencesForPropertyInSource: [aProperty name]];
                }
            }
            else
            {
                [(COObject *)aValue removeReferencesForPropertyInSource: [aProperty name]];
            }
        }
    }
}

- (void) addCachedOutgoingRelationshipsForValue: (id)aValue
                      ofPropertyWithDescription: (ETPropertyDescription *)aProperty
                                       ofObject: (COObject *)anObject

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
                        [[obj relationshipCache] addReferenceFromSourceObject: anObject
                                                               sourceProperty: [aProperty name]
                                                               targetProperty: [propertyInTarget name]];
                    }
                }
                else
                {
                    [[(COObject *)aValue relationshipCache] addReferenceFromSourceObject: anObject
                                                                          sourceProperty: [aProperty name]
                                                                          targetProperty: [propertyInTarget name]];
                }
            }
        }
    }
}

- (void) updateCachedOutgoingRelationshipsForOldValue: (id)oldVal
                                             newValue: (id)newVal
                            ofPropertyWithDescription: (ETPropertyDescription *)aProperty
                                             ofObject: (COObject *)anObject
{
    if (isPersistentCoreObjectReferencePropertyDescription(aProperty))
    {
        [self removeCachedOutgoingRelationshipsForValue: oldVal
                              ofPropertyWithDescription: aProperty
                                               ofObject: anObject];
        
        [self addCachedOutgoingRelationshipsForValue: newVal
                           ofPropertyWithDescription: aProperty
                                            ofObject: anObject];
    }
}

- (void) addCachedOutgoingRelationshipsForObject: (COObject *)anObject
{
    for (ETPropertyDescription *prop in [[anObject entityDescription] propertyDescriptions])
    {
        if (isPersistentCoreObjectReferencePropertyDescription(prop))
        {
            id value = [anObject valueForKey: [prop name]];
            
            [self addCachedOutgoingRelationshipsForValue: value
                               ofPropertyWithDescription: prop
                                                ofObject: anObject];
        }
    }
}

- (void) removeCachedOutgoingRelationshipsForObject: (COObject *)anObject
{
    for (ETPropertyDescription *prop in [[anObject entityDescription] propertyDescriptions])
    {
        if (isPersistentCoreObjectReferencePropertyDescription(prop))
        {
            id value = [anObject valueForKey: [prop name]];
            
            [self removeCachedOutgoingRelationshipsForValue: value
                                  ofPropertyWithDescription: prop
                                                   ofObject: anObject];
        }
    }
}

@end
