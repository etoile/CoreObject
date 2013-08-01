#import "COItemGraph.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import "COItem.h"
#import "COItem+JSON.h"

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
- (BOOL) isEqual:(id)object
{
    //NSLog(@"WARNING, COItemGraph should be compared for debugging only");
    
    if (![object isKindOfClass: [self class]])
    {
        return NO;
    }
    
    return COItemGraphEqualToItemGraph(self, object);
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

NSData *COItemGraphToJSONData(id<COItemGraph> aGraph)
{
    NSMutableDictionary *objectsDict = [NSMutableDictionary dictionary];
    for (ETUUID *uuid in [aGraph itemUUIDs])
    {
        COItem *item = [aGraph itemForUUID: uuid];
        id objectPlist = [item JSONPlist];
        [objectsDict setObject: objectPlist
                        forKey: [uuid stringValue]];
    }
    
    NSDictionary *graphDict = D(objectsDict, @"objects",
                                [[aGraph rootItemUUID] stringValue], @"rootObjectUUID");
    
    return [NSJSONSerialization dataWithJSONObject: graphDict options: 0 error: NULL];
}

COItemGraph *COItemGraphFromJSONData(NSData *json)
{
    id plist = [NSJSONSerialization JSONObjectWithData: json options:0 error: NULL];
    id objectsPlist = [plist objectForKey: @"objects"];
    ETUUID *rootObjectUUID = [ETUUID UUIDWithString: [plist objectForKey: @"rootObjectUUID"]];
    NSMutableDictionary *itemForUUID = [NSMutableDictionary dictionary];
    
    for (NSString *uuidString in objectsPlist)
    {
        COItem *item = [[COItem alloc] initWithJSONPlist: [objectsPlist objectForKey: uuidString]];
        [itemForUUID setObject: item
                        forKey: [item UUID]];
        [item release];
    }
    
    COItemGraph *graph = [[COItemGraph alloc] initWithItemForUUID: itemForUUID
                                                     rootItemUUID: rootObjectUUID];
    return graph;
}

/**
 * For debugging/testing only
 */
static BOOL COItemGraphEqualToItemGraphComparingItemUUID(id<COItemGraph> first, id<COItemGraph> second, ETUUID *aUUID)
{
    COItem *my = [first itemForUUID: aUUID];
    COItem *other = [second itemForUUID: aUUID];
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
        if (!COItemGraphEqualToItemGraphComparingItemUUID(first, second, aChild))
        {
            return NO;
        }
    }
    return YES;
}

BOOL COItemGraphEqualToItemGraph(id<COItemGraph> first, id<COItemGraph> second)
{
    if (![[first rootItemUUID] isEqual: [second rootItemUUID]])
    {
        return NO;
    }
    
    return COItemGraphEqualToItemGraphComparingItemUUID(first, second, [first rootItemUUID]);
}
