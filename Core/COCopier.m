#import "COCopier.h"
#import "COItem.h"

@implementation COCopier

- (void) collectItemAndAllDescendents: (ETUUID *)aUUID
                                inSet: (NSMutableSet *)dest
                            fromGraph: (id<COItemGraph>)source
{
    [dest addObject: aUUID];
    for (ETUUID *child in [[source itemForUUID: aUUID] embeddedItemUUIDs])
    {
        if (![dest containsObject: child])
        {
            [self collectItemAndAllDescendents: child
                                         inSet: dest
                                     fromGraph: source];
        }
        else
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"Cycle detected"];
        }
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
