#import "COObject+RelationshipCache.h"
#import "COObject.h"
#import "CORelationshipCache.h"
#import <EtoileFoundation/EtoileFoundation.h>

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
                    [[obj relationshipCache] removeReferencesForPropertyInSource: [aProperty name]];
                }
            }
            else
            {
                [[(COObject *)aValue relationshipCache] removeReferencesForPropertyInSource: [aProperty name]];
            }
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
                        [[obj relationshipCache] addReferenceFromSourceObject: self
                                                               sourceProperty: [aProperty name]
                                                               targetProperty: [propertyInTarget name]];
                    }
                }
                else
                {
                    [[(COObject *)aValue relationshipCache] addReferenceFromSourceObject: self
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
