#import "COItemGraph.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import "COItem.h"

@implementation COItemGraph

- (id) initWithItemForUUID: (NSDictionary *) itemForUUID
              rootItemUUID: (ETUUID *)root
{
    SUPERINIT;
    itemForUUID_ = [itemForUUID mutableCopy];
    rootItemUUID_ = [root copy];
    return self;
}

- (id) initWithItems: (NSArray *)items
        rootItemUUID: (ETUUID *)root
{
    SUPERINIT;
    itemForUUID_ = [[NSMutableDictionary alloc] init];
    rootItemUUID_ = [root copy];
    
    for (COItem *item in items)
    {
        [itemForUUID_ setObject: item forKey: [item UUID]];
    }
    NSParameterAssert([itemForUUID_ objectForKey: root] != nil);
    
    return self;
}


+ (COItemGraph *)treeWithItemsRootFirst: (NSArray*)items
{
    NSParameterAssert([items count] >= 1);

    COItemGraph *result = [[[self alloc] init] autorelease];
    result->rootItemUUID_ = [[[items objectAtIndex: 0] UUID] copy];
    result->itemForUUID_ = [[NSMutableDictionary alloc] initWithCapacity: [items count]];
    
    for (COItem *item in items)
    {
        [result->itemForUUID_ setObject: item forKey: [item UUID]];
    }
    return result;
}

- (void) dealloc
{
    [itemForUUID_ release];
    [rootItemUUID_ release];
    [super dealloc];
}


- (ETUUID *) rootItemUUID
{
    return rootItemUUID_;
}

- (COMutableItem *) itemForUUID: (ETUUID *)aUUID
{
    return [itemForUUID_ objectForKey: aUUID];
}

- (NSArray *) itemUUIDs
{
    return [itemForUUID_ allKeys];
}

- (NSString *)description
{
	NSMutableString *result = [NSMutableString string];
    
	[result appendFormat: @"[%@ root: %@\n", NSStringFromClass([self class]), rootItemUUID_];
	for (COItem *item in [itemForUUID_ allValues])
	{
		[result appendFormat: @"%@", item];
	}
	[result appendFormat: @"]"];
	
	return result;
}

- (void) insertOrUpdateItems: (NSArray *)items
{
    for (COItem *anItem in items)
    {
        [itemForUUID_ setObject: anItem
                         forKey: [anItem UUID]];
    }
}

/**
 * For debugging/testing only
 */
- (BOOL) isEqualToItemTree: (COItemGraph *)aTree
         comparingItemUUID: (ETUUID *)aUUID
{
    COItem *my = [self itemForUUID: aUUID];
    COItem *other = [aTree itemForUUID: aUUID];
    if (![my isEqual: other])
    {
        return NO;
    }
    
    if (![[my embeddedItemUUIDs] isEqual: [other embeddedItemUUIDs]])
    {
        return NO;
    }
    
    for (ETUUID *aChild in [my embeddedItemUUIDs])
    {
        if (![self isEqualToItemTree: aTree comparingItemUUID: aChild])
        {
            return NO;
        }
    }
    return YES;
}

/**
 * For debugging/testing only
 */
- (BOOL) isEqual:(id)object
{
    //NSLog(@"WARNING, COItemGraph should be compared for debugging only");
    
    if (![object isKindOfClass: [self class]])
    {
        return NO;
    }
    if (![[object rootItemUUID] isEqual: rootItemUUID_])
    {
        return NO;
    }
    return [self isEqualToItemTree: object comparingItemUUID: rootItemUUID_];
}

@end


/**
 * For debugging
 */
void COValidateItemGraph(id<COItemGraph> aGraph)
{
    if (nil == [aGraph itemForUUID: [aGraph rootItemUUID]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Graph root item is missing"];
    }
    
    NSSet *uuidSet = [NSSet setWithArray: [aGraph itemUUIDs]];
    
    for (ETUUID *uuid in [aGraph itemUUIDs])
    {
        COItem *item = [aGraph itemForUUID: uuid];
        
        for (NSString *key in [item attributeNames])
        {
            id value = [item valueForAttribute: key];
            COType type = [item typeForAttribute: key];
            
            // Check that the value conforms to the COType
            
            if (!COTypeValidateObject(type, value))
            {
                [NSException raise: NSInvalidArgumentException
                            format: @"Property value %@ for key %@ (type %@) of object %@ is not valid",
                                    value, key, COTypeDescription(type), uuid];
            }
            
            // Check that all inner references can be resolved
            
            if (COPrimitiveType(type) == kCOReferenceType
                || COPrimitiveType(type) == kCOCompositeReferenceType)
            {
                for (id subValue in
                     [value respondsToSelector: @selector(objectEnumerator)] ? value : [NSArray arrayWithObject: value])
                {
                    if ([subValue isKindOfClass: [ETUUID class]])
                    {
                        if (![uuidSet containsObject: subValue])
                        {
                            [NSException raise: NSInvalidArgumentException
                                        format: @"Object %@ has broken inner object reference %@", uuid, subValue];
                        }
                    }
                }
            }
        }
    }
}

