/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  May 2013
	License:  MIT  (see COPYING)
 */

#import "COCopier.h"
#import "COItem.h"
#import "COSerialization.h"

@implementation COCopier

- (NSArray *) directDescendentItemUUIDsForUUID: (ETUUID *)aUUID
									 fromGraph: (id<COItemGraph>)source
{
	NSMutableSet *result = [NSMutableSet set];
	
	COItem *item = [source itemForUUID: aUUID];
	for (NSString *key in [item attributeNames])
	{
		COType type = [item typeForAttribute: key];
		if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
		{
			[result addObjectsFromArray: [item allObjectsForAttribute: key]];
		}
		else if (COTypePrimitivePart(type) == kCOTypeReference)
		{
			for (ETUUID *refUUID in [item allObjectsForAttribute: key])
			{
				if ([refUUID isKindOfClass: [ETUUID class]])
				{
					COItem *refItem = [source itemForUUID: refUUID];
					if ([[refItem valueForAttribute: kCOObjectIsSharedProperty] isEqual: @NO])
					{
						[result addObject: refUUID];
					}
				}
			}
		}
	}
	
	return [result allObjects];
}

- (void) collectItemAndAllDescendents: (ETUUID *)aUUID
                                inSet: (NSMutableSet *)dest
                            fromGraph: (id<COItemGraph>)source
{
	if ([dest containsObject: aUUID])
	{
		return;
	}

    [dest addObject: aUUID];
	
    for (ETUUID *child in [self directDescendentItemUUIDsForUUID: aUUID fromGraph: source])
    {
		[self collectItemAndAllDescendents: child
									 inSet: dest
								 fromGraph: source];
    }
}

- (NSSet*) itemAndAllDescendents: (ETUUID *)aUUID
                       fromGraph: (id<COItemGraph>)source
{
    NSMutableSet *result = [NSMutableSet set];
    [self collectItemAndAllDescendents: aUUID inSet: result fromGraph: source];
    return result;
}



- (NSSet *) itemUUIDsToCopyForItemItemWithUUID: (ETUUID*)aUUID
                                     fromGraph: (id<COItemGraph>)source
                                       toGraph: (id<COItemGraph>)dest
{
    NSSet *compositeObjectCopySet = [self itemAndAllDescendents: aUUID fromGraph: source];
 
    NSMutableSet *result = [NSMutableSet setWithSet: compositeObjectCopySet];
    
    for (ETUUID *uuid in compositeObjectCopySet)
    {
		// FIXME: This isn't intuitive... we just copy one layer deep of non-composite references 		
		// FIXME: referencedItemUUIDs ignores composite references, which sounds wrong! Test!
        for (ETUUID *referenced in [[source itemForUUID: uuid] referencedItemUUIDs])
        {
            if (![compositeObjectCopySet containsObject: referenced])
            {
                if ([dest itemForUUID: referenced] == nil)
                {
                    // If not in dest, copy it
                    [result addObject: referenced];
                }
            }
        }
    }
    return result;
}


- (ETUUID*) copyItemWithUUID: (ETUUID*)aUUID
                   fromGraph: (id<COItemGraph>)source
                     toGraph: (id<COItemGraph>)dest
{
	NILARG_EXCEPTION_TEST(aUUID);
	NILARG_EXCEPTION_TEST(source);
	NILARG_EXCEPTION_TEST(dest);
	
    NSSet *uuidsToCopy = [self itemUUIDsToCopyForItemItemWithUUID: aUUID
                                                        fromGraph: source
                                                          toGraph: dest];
    
    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
    for (ETUUID *oldUUID in uuidsToCopy)
    {
        [mapping setObject: [ETUUID UUID]
                    forKey: oldUUID];
    }
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (ETUUID *uuid in uuidsToCopy)
    {
        COItem *oldItem = [source itemForUUID: uuid];
        COItem *newItem = [oldItem mutableCopyWithNameMapping: mapping];
        [result addObject: newItem];
    }
    
    [dest insertOrUpdateItems: result];
    
    return [mapping objectForKey: aUUID];
}

@end
