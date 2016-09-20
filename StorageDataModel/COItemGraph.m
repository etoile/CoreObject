/*
    Copyright (C) 2012 Eric Wasylishen

    Date:  December 2012
    License:  MIT  (see COPYING)
 */

#import "COItemGraph.h"
#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETUUID.h>
#import "COItem.h"
#import "COItem+JSON.h"
#import "COItem+Binary.h"
#import "COPath.h"
#import "COJSONSerialization.h"
#import "COSQLiteStorePersistentRootBackingStoreBinaryFormats.h"
#import "COSQLiteStorePersistentRootBackingStore.h"

@implementation COItemGraph

- (instancetype) init
{
	return [self initWithItemForUUID: @{} rootItemUUID: nil];
}

- (instancetype) initWithItemForUUID: (NSDictionary *) itemForUUID
                        rootItemUUID: (ETUUID *)root
{
    SUPERINIT;
    itemForUUID_ = [itemForUUID mutableCopy];
    rootItemUUID_ = [root copy];
    return self;
}

- (instancetype) initWithItems: (NSArray *)items
                  rootItemUUID: (ETUUID *)root
{
    self = [self initWithItemForUUID: @{} rootItemUUID: root];
	if (self == nil)
		return nil;
    
    for (COItem *item in items)
    {
        itemForUUID_[item.UUID] = item;
    }
    
    return self;
}

- (instancetype) initWithItemGraph: (id<COItemGraph>)aGraph
{
    NSMutableArray *array = [NSMutableArray array];
    
    for (ETUUID *uuid in aGraph.itemUUIDs)
    {
        COItem *item = [aGraph itemForUUID: uuid];
        [array addObject: item];
    }
    
    return [self initWithItems: array rootItemUUID: aGraph.rootItemUUID];
}

+ (COItemGraph *)itemGraphWithItemsRootFirst: (NSArray*)items
{
    NSParameterAssert([items count] >= 1);

    COItemGraph *result = [[self alloc] init];
    result->rootItemUUID_ = [[items[0] UUID] copy];
    result->itemForUUID_ = [[NSMutableDictionary alloc] initWithCapacity: items.count];
    
    for (COItem *item in items)
    {
        result->itemForUUID_[item.UUID] = item;
    }
    return result;
}

@synthesize rootItemUUID = rootItemUUID_;

- (COMutableItem *) itemForUUID: (ETUUID *)aUUID
{
    return itemForUUID_[aUUID];
}

- (NSArray *) itemUUIDs
{
    return itemForUUID_.allKeys;
}

- (NSArray *) items
{
	return itemForUUID_.allValues;
}

- (NSString *)description
{
	NSMutableString *result = [NSMutableString string];
    
	[result appendFormat: @"[%@ root: %@\n", NSStringFromClass([self class]), rootItemUUID_];
	for (COItem *item in itemForUUID_.allValues)
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
        itemForUUID_[anItem.UUID] = anItem;
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

- (void) addItemGraph: (id<COItemGraph>)aGraph
{
    rootItemUUID_ = aGraph.rootItemUUID;
    for (ETUUID *uuid in aGraph.itemUUIDs)
    {
        COItem *item = [aGraph itemForUUID: uuid];
        if (item != nil)
        {
            itemForUUID_[uuid] = item;
        }
    }
}

- (void)removeUnreachableItems
{
	NSSet *reachableUUIDs = COItemGraphReachableUUIDs(self);

	NSMutableSet *unreachableUUIDs = [NSMutableSet setWithArray: itemForUUID_.allKeys];
	[unreachableUUIDs minusSet: reachableUUIDs];
	
	[itemForUUID_ removeObjectsForKeys: unreachableUUIDs.allObjects];
}

@end


/**
 * For debugging
 */
void COValidateItemGraph(id<COItemGraph> aGraph)
{
    if (nil == [aGraph itemForUUID: aGraph.rootItemUUID])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Graph root item is missing"];
    }
    
    NSSet *uuidSet = [NSSet setWithArray: aGraph.itemUUIDs];
    
    for (ETUUID *uuid in aGraph.itemUUIDs)
    {
        COItem *item = [aGraph itemForUUID: uuid];
        
        for (NSString *key in item.attributeNames)
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
            
            if (COTypePrimitivePart(type) == kCOTypeReference
                || COTypePrimitivePart(type) == kCOTypeCompositeReference)
            {
                for (id subValue in
                     [value respondsToSelector: @selector(objectEnumerator)] ? value : @[value])
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

id COItemGraphToJSONPropertyList(id<COItemGraph> aGraph)
{
    NSMutableDictionary *objectsDict = [NSMutableDictionary dictionary];
    for (ETUUID *uuid in aGraph.itemUUIDs)
    {
        COItem *item = [aGraph itemForUUID: uuid];
        id objectPlist = item.JSONPlist;
        objectsDict[[uuid stringValue]] = objectPlist;
    }
    
    return @{@"objects" : objectsDict,
             @"rootObjectUUID" : [aGraph.rootItemUUID stringValue]};
}

NSData *COItemGraphToJSONData(id<COItemGraph> aGraph)
{
    NSDictionary *graphDict = COItemGraphToJSONPropertyList(aGraph);    
    return CODataWithJSONObject(graphDict, NULL);
}

COItemGraph *COItemGraphFromJSONPropertyLisy(id plist)
{
    id objectsPlist = plist[@"objects"];
    ETUUID *rootObjectUUID = [ETUUID UUIDWithString: plist[@"rootObjectUUID"]];
    NSMutableDictionary *itemForUUID = [NSMutableDictionary dictionary];
    
    for (NSString *uuidString in objectsPlist)
    {
        COItem *item = [[COItem alloc] initWithJSONPlist: objectsPlist[uuidString]];
        itemForUUID[item.UUID] = item;
    }
    
    COItemGraph *graph = [[COItemGraph alloc] initWithItemForUUID: itemForUUID
                                                     rootItemUUID: rootObjectUUID];
    return graph;
}

COItemGraph *COItemGraphFromJSONData(NSData *json)
{
    id plist = COJSONObjectWithData(json, NULL);
    return COItemGraphFromJSONPropertyLisy(plist);
}

static const NSString *BinaryHeaderString = @"CoreObjectBinaryItemGraph";

NSData *COItemGraphToBinaryData(id<COItemGraph> aGraph)
{
    // format:
    // 'CoreObjectBinaryItemGraph' (ASCII)
    // 1 (version number - uint32, little endian)
    // 16-byte UUID of root item
    // [ item data block, same format as used for COSQLiteStore ]

    if (aGraph == nil)
    {
        [NSException raise: NSInvalidArgumentException format: @"Expected aGraph != nil"];
    }
    
    NSMutableData *result = [NSMutableData data];
    [result appendData: [BinaryHeaderString dataUsingEncoding: NSUTF8StringEncoding]];
    
    const uint32_t version = NSSwapHostIntToLittle(1);
    [result appendBytes: &version length: sizeof(version)];
    [result appendData: [aGraph.rootItemUUID dataValue]];
    [result appendData: contentsBLOBWithItemTree(aGraph)];
    return result;
}

COItemGraph *COItemGraphFromBinaryData(NSData *binarydata)
{
    const NSUInteger formatLen = BinaryHeaderString.length;
    const NSUInteger versionLen = 4;
    const NSUInteger uuidLen = 16;
    
    NSUInteger pos = 0;
    NSData *formatData = [binarydata subdataWithRange: NSMakeRange(pos, formatLen)];
    pos += formatLen;
    NSData *versionData = [binarydata subdataWithRange: NSMakeRange(pos, versionLen)];
    pos += versionLen;
    NSData *uuidData = [binarydata subdataWithRange: NSMakeRange(pos, uuidLen)];
    pos += uuidLen;
    NSData *itemsData = [binarydata subdataWithRange: NSMakeRange(pos, binarydata.length - pos)];
    
    // Check format
    NSString *formatStr = [[NSString alloc] initWithData: formatData encoding: NSUTF8StringEncoding];
    if(![formatStr isEqual: BinaryHeaderString])
    {
        [NSException raise: NSInvalidArgumentException format: @"Incorrect header"];
    }
    
    // Check version
    uint32_t version;
    [versionData getBytes:&version length:versionLen];
    version = NSSwapLittleIntToHost(version);
    if (version != 1)
    {
        [NSException raise: NSInvalidArgumentException format: @"Expected version 1"];
    }
    
    // Get root item UUID
    ETUUID *rootItemUUID = [ETUUID UUIDWithData:uuidData];
    
    // Parse [UUID, item data] blocks
    NSMutableDictionary *dataForUUID = [NSMutableDictionary dictionary];
    ParseCombinedCommitDataInToUUIDToItemDataDictionary(dataForUUID, itemsData, NO, nil);
    
    // Parse the COItem instances from n
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    for (ETUUID *uuid in dataForUUID)
    {
        NSData *data = dataForUUID[uuid];
        COItem *item = [[COItem alloc] initWithData: data];
        resultDict[uuid] = item;
    }
    
    COItemGraph *result = [[COItemGraph alloc] initWithItemForUUID: resultDict
                                                      rootItemUUID: rootItemUUID];
    return result;
}

/**
 * For debugging/testing only
 */
static BOOL COItemGraphEqualToItemGraphComparingItemUUID(id<COItemGraph> first, id<COItemGraph> second, ETUUID *aUUID)
{
    COItem *my = [first itemForUUID: aUUID];
    COItem *other = [second itemForUUID: aUUID];
	if (my == nil && other == nil)
	{
		// both item graphs are missing the same item
		return YES;
	}
	
    if (![my isEqual: other])
    {
        return NO;
    }
    
    if (![my.compositeReferencedItemUUIDs isEqual: other.compositeReferencedItemUUIDs])
    {
        return NO;
    }
    
    for (ETUUID *aChild in my.compositeReferencedItemUUIDs)
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
    if (![first.rootItemUUID isEqual: second.rootItemUUID])
    {
        return NO;
    }
    
    return COItemGraphEqualToItemGraphComparingItemUUID(first, second, first.rootItemUUID);
}

static void
COItemGraphReachableUUIDsInternal(id<COItemGraph> aGraph, ETUUID *aUUID, NSMutableSet *result)
{
	if (![aUUID isKindOfClass: [ETUUID class]])
	{
		[NSException raise: NSInvalidArgumentException format: @"Expected ETUUID argument to COItemGraphReachableUUIDsInternal, got %@", aUUID];
	}
	
	if ([result containsObject: aUUID])
		return;
	
	[result addObject: aUUID];
	
    COItem *item = [aGraph itemForUUID: aUUID];
    for (id aChild in item.allInnerReferencedItemUUIDs)
    {
        COItemGraphReachableUUIDsInternal(aGraph, aChild, result);
    }
}

NSSet *
COItemGraphReachableUUIDs(id<COItemGraph> aGraph)
{
    NSMutableSet *result = [NSMutableSet new];
	if (aGraph.rootItemUUID != nil)
	{
		COItemGraphReachableUUIDsInternal(aGraph, aGraph.rootItemUUID, result);
	}
	return result;
}
