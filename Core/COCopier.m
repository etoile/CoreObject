/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  May 2013
    License:  MIT  (see COPYING)
 */

#import "COCopier.h"
#import "COItem.h"

@implementation COCopier

- (void)collectItemUUIDsToCopyForItem: (COItem *)item
                                inSet: (NSMutableSet *)result
                            fromGraph: (id <COItemGraph>)source
                              toGraph: (id <COItemGraph>)dest
                        destItemUUIDs: (NSSet *)destItemUUIDs
                              options: (COCopierOptions)options
{
    for (NSString *key in item.attributeNames)
    {
        COType type = [item typeForAttribute: key];

        if (COTypePrimitivePart(type) == kCOTypeCompositeReference)
        {
            for (ETUUID *ref in [item allObjectsForAttribute: key])
            {
                if ([result containsObject: ref])
                    continue;

                [result addObject: ref];
                [self collectItemUUIDsToCopyForItem: [source itemForUUID: ref]
                                              inSet: result
                                          fromGraph: source
                                            toGraph: dest
                                      destItemUUIDs: destItemUUIDs
                                            options: options];
            }
        }
        else if (COTypePrimitivePart(type) == kCOTypeReference)
        {
            for (id ref in [item allObjectsForAttribute: key])
            {
                if (![ref isKindOfClass: [ETUUID class]] || [result containsObject: ref])
                    continue;

                COItem *refItem = [source itemForUUID: ref];
                BOOL copied = NO;

                if ([destItemUUIDs containsObject: ref])
                {
                    if (options & COCopierCopiesNonCompositeReferencesExistingInDestination)
                    {
                        [result addObject: ref];
                        copied = YES;
                    }
                    else if ([[refItem valueForAttribute: kCOItemIsSharedProperty] isEqual: @NO])
                    {
                        [result addObject: ref];
                        copied = YES;
                    }
                }
                else if (options & COCopierCopiesNonCompositeReferencesMissingInDestination)
                {
                    [result addObject: ref];
                    copied = YES;
                }
                
                if (!copied)
                    continue;

                [self collectItemUUIDsToCopyForItem: refItem
                                              inSet: result
                                          fromGraph: source
                                            toGraph: dest
                                      destItemUUIDs: destItemUUIDs
                                            options: options];
            }
        }
    }
}

- (NSSet *)itemUUIDsToCopyForItemWithUUID: (ETUUID *)aUUID
                                fromGraph: (id <COItemGraph>)source
                                  toGraph: (id <COItemGraph>)dest
                                  options: (COCopierOptions)options
{
    NSMutableSet *result = [NSMutableSet setWithObject: aUUID];
    NSSet *destItemUUIDs = [NSSet setWithArray: dest.itemUUIDs];
    
    [self collectItemUUIDsToCopyForItem: [source itemForUUID: aUUID]
                                  inSet: result
                              fromGraph: source
                                toGraph: dest
                          destItemUUIDs: destItemUUIDs
                                options: options];

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

    for (ETUUID *uuid in uuidsToCopy)
    {
        COItem *oldItem = [source itemForUUID: uuid];
        COItem *newItem = [oldItem mutableCopyWithUUIDMapping: mapping];

        [items addObject: newItem];
    }

    [dest insertOrUpdateItems: items];

    return [uuids mappedCollectionWithBlock: ^(id inputUUID) { return mapping[inputUUID]; }];
}

@end
