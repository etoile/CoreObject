/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  May 2013
    License:  MIT  (see COPYING)
 */

#import "COCopier.h"
#import "COItem.h"

@implementation COCopier

- (NSArray *)directDescendentItemUUIDsForUUID: (ETUUID *)aUUID
                                    fromGraph: (id <COItemGraph>)source
{
    NSMutableSet *result = [NSMutableSet set];
    COItem *item = [source itemForUUID: aUUID];

    for (NSString *key in item.attributeNames)
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

                    if ([[refItem valueForAttribute: kCOItemIsSharedProperty] isEqual: @NO])
                    {
                        [result addObject: refUUID];
                    }
                }
            }
        }
    }

    return result.allObjects;
}

- (void)collectUUIDsForItemAndAllDescendents: (ETUUID *)aUUID
                                       inSet: (NSMutableSet *)dest
                                   fromGraph: (id <COItemGraph>)source
{
    if ([dest containsObject: aUUID])
        return;

    [dest addObject: aUUID];

    for (ETUUID *child in [self directDescendentItemUUIDsForUUID: aUUID fromGraph: source])
    {
        [self collectUUIDsForItemAndAllDescendents: child
                                             inSet: dest
                                         fromGraph: source];
    }
}

- (NSSet *)UUIDsForItemAndAllDescendents: (ETUUID *)aUUID
                               fromGraph: (id <COItemGraph>)source
{
    NSMutableSet *result = [NSMutableSet set];
    [self collectUUIDsForItemAndAllDescendents: aUUID inSet: result fromGraph: source];
    return result;
}

- (void)collectNonCompositeItemUUIDsToCopyForItem: (COItem *)item
                                            inSet: (NSMutableSet *)result
                                        fromGraph: (id <COItemGraph>)source
                                          toGraph: (id <COItemGraph>)dest
                                    destItemUUIDs: (NSSet *)destItemUUIDs
                                          options: (COCopierOptions)options
{
    for (ETUUID *reference in item.referencedItemUUIDs)
    {
        if ([result containsObject: reference])
            continue;
        
        // Don't use -itemForUUID: to check existence, since it can trigger a serialization
        if ([destItemUUIDs containsObject: reference])
        {
            if (options & COCopierCopiesNonCompositeReferencesExistingInDestination) {
                [result addObject: reference];
            }
        } else if (options & COCopierCopiesNonCompositeReferencesMissingInDestination) {
            [result addObject: reference];
        }
        
        [self collectNonCompositeItemUUIDsToCopyForItem: [source itemForUUID: reference]
                                                  inSet: result
                                              fromGraph: source
                                                toGraph: dest
                                          destItemUUIDs: destItemUUIDs
                                                options: options];
    }
}

- (NSSet *)itemUUIDsToCopyForItemWithUUID: (ETUUID *)aUUID
                                fromGraph: (id <COItemGraph>)source
                                  toGraph: (id <COItemGraph>)dest
                                  options: (COCopierOptions)options
{
    NSSet *compositeItemUUIDs = [self UUIDsForItemAndAllDescendents: aUUID fromGraph: source];
    NSMutableSet *result = [NSMutableSet setWithSet: compositeItemUUIDs];
    NSSet *destItemUUIDs = [NSSet setWithArray: dest.itemUUIDs];
    BOOL copiesNonCompositeReferences = (options & COCopierCopiesNonCompositeReferencesMissingInDestination)
                                     || (options & COCopierCopiesNonCompositeReferencesExistingInDestination);
    
    if (copiesNonCompositeReferences)
    {
        for (ETUUID *uuid in compositeItemUUIDs)
        {
            [self collectNonCompositeItemUUIDsToCopyForItem: [source itemForUUID: uuid]
                                                      inSet: result
                                                  fromGraph: source
                                                    toGraph: dest
                                              destItemUUIDs: destItemUUIDs
                                                    options: options];
        }
    }

    return result;
}

- (ETUUID *)copyItemWithUUID: (ETUUID *)aUUID
                   fromGraph: (id <COItemGraph>)source
                     toGraph: (id <COItemGraph>)dest
                     options: (COCopierOptions)options
{
    NILARG_EXCEPTION_TEST(aUUID);
    return [self copyItemsWithUUIDs: @[aUUID] 
                          fromGraph: source 
                            toGraph: dest 
                            options: options][0];
}

- (ETUUID *)copyItemWithUUID: (ETUUID *)aUUID
                   fromGraph: (id <COItemGraph>)source
                     toGraph: (id <COItemGraph>)dest
{
    NILARG_EXCEPTION_TEST(aUUID);
    return [self copyItemsWithUUIDs: @[aUUID]
                          fromGraph: source
                            toGraph: dest
                            options: 0][0];
}

- (NSArray *)copyItemsWithUUIDs: (NSArray *)uuids
                      fromGraph: (id <COItemGraph>)source
                        toGraph: (id <COItemGraph>)dest
                        options: (COCopierOptions)options
{
    NILARG_EXCEPTION_TEST(uuids);
    NILARG_EXCEPTION_TEST(source);
    NILARG_EXCEPTION_TEST(dest);

    NSMutableSet *uuidsToCopy = [NSMutableSet new];

    for (ETUUID *uuid in uuids)
    {
        [uuidsToCopy unionSet: [self itemUUIDsToCopyForItemWithUUID: uuid
                                                          fromGraph: source
                                                            toGraph: dest
                                                            options: options]];
    }

    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];

    for (ETUUID *oldUUID in uuidsToCopy)
    {
        mapping[oldUUID] = (options & COCopierReusesSourceUUIDs) ? oldUUID :  [ETUUID UUID];
    }

    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *itemUUIDs = [NSMutableArray array];

    for (ETUUID *uuid in uuidsToCopy)
    {
        COItem *oldItem = [source itemForUUID: uuid];
        COItem *newItem = [oldItem mutableCopyWithUUIDMapping: mapping];

        [items addObject: newItem];
        [itemUUIDs addObject: newItem.UUID];
    }

    [dest insertOrUpdateItems: items];

    return [uuids mappedCollectionWithBlock: ^(id inputUUID) { return mapping[inputUUID]; }];
}

@end
