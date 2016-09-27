/**
    Copyright (C) 2012 Eric Wasylishen

    Date:  December 2012
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>

@class ETUUID;
@class COItem, COMutableItem;

/**
 * @group Storage Data Model
 * @abstract
 * Protocol for a mutable item graph.
 *
 * @section Object Model
 *
 * All objects must have a composite or non-composite relationship path to the root
 * (garbage-collected graph approach). This can be violated in the short term while
 * making a batch of changes.
 *
 * Garbage collection is not covered by this protocol.
 */
@protocol COItemGraph <NSObject>

/**
 * Returns the entry point UUID.
 */
@property (nonatomic, readonly) ETUUID *rootItemUUID;
/**
 * Returns an immutable item for the UUID.
 */
- (COItem *)itemForUUID: (ETUUID *)aUUID;
/**
 * Returns all the item UUIDs in the graph, including -rootItemUUID.
 */
@property (nonatomic, readonly) NSArray *itemUUIDs;
/**
 * Returns all the items in the graph.
 *
 * The returned item count is the same than -itemUUIDs.
 */
@property (nonatomic, readonly) NSArray *items;
/**
 * Inserts the items in the graph, or updates existing items when the graph 
 * contains items with matching UUIDs.
 *
 * When combined with the receiver, all inner references should be resolved.
 *
 * May broadcast a change notification, up to the subclass.
 */
- (void)insertOrUpdateItems: (NSArray *)items;
@end

/**
 * @group Storage Data Model
 * @abstract
 * An item graph is a mutable set of COItem objects, and a root item UUID, which
 * is the designated entry point to the object graph.
 *
 * COItemGraph is allowed to contain broken references (i.e. it can contain
 * COItems which have ETUUID references to items not in the COItemGraph, or
 * even be missing the COItem for the root item UUID) - this is to allow 
 * COItemGraph to act as a simple delta mechanism, so you can compute 
 * <em>(COItemGraph + COItemGraph) = a new COItemGraph</em>.
 */
@interface COItemGraph : NSObject <COItemGraph>
{
    ETUUID *rootItemUUID_;
    NSMutableDictionary *itemForUUID_;
}

/** @taskunit Initialization */


+ (COItemGraph *)itemGraphWithItemsRootFirst: (NSArray *)items;
/**
 * N.B. items doesn't need to contain rootItemUUID.
 */
- (instancetype)initWithItemForUUID: (NSDictionary *)itemForUUID
                       rootItemUUID: (ETUUID *)root NS_DESIGNATED_INITIALIZER;
/**
 * N.B. items doesn't need to contain rootItemUUID.
 */
- (instancetype)initWithItems: (NSArray *)items
                 rootItemUUID: (ETUUID *)root;
- (instancetype)initWithItemGraph: (id <COItemGraph>)aGraph;


/** @taskunit Item Graph Protocol and Additionss */

/**
 * See -[COItemGraph rootItemUUID].
 */
@property (nonatomic, strong) ETUUID *rootItemUUID;
/**
 * See -[COItemGraph itemForUUID:].
 */
- (COMutableItem *)itemForUUID: (ETUUID *)aUUID;
/**
 * See -[COItemGraph itemUUIDs].
 */
@property (nonatomic, readonly) NSArray *itemUUIDs;
/**
 * Returns all the items in the graph.
 *
 * The returned item count is the same than -itemUUIDs.
 */
@property (nonatomic, readonly) NSArray *items;
/**
 * See -[COItemGraph insertOrUpdateItems:].
 */
- (void)insertOrUpdateItems: (NSArray *)items;
/**
 * Adds the items from the given item graph to the receiver.
 *
 * If two items have the same UUID, the added item replaces the one in the 
 * receiver.
 */
- (void)addItemGraph: (id <COItemGraph>)aGraph;
/**
 * Removes all unreachable items.
 */
- (void)removeUnreachableItems;

@end

/**
 * For debugging.
 */
void COValidateItemGraph(id <COItemGraph> aGraph);

id COItemGraphToJSONPropertyList(id <COItemGraph> aGraph);
NSData *COItemGraphToJSONData(id <COItemGraph> aGraph);

COItemGraph *COItemGraphFromJSONPropertyLisy(id plist);
COItemGraph *COItemGraphFromJSONData(NSData *json);

NSData *COItemGraphToBinaryData(id <COItemGraph> aGraph);
COItemGraph *COItemGraphFromBinaryData(NSData *binarydata);

BOOL COItemGraphEqualToItemGraph(id <COItemGraph> first, id <COItemGraph> second);

/**
 * If <code>aGraph.rootItemUUID</code> is nil, returns the empty set.
 */
NSSet *COItemGraphReachableUUIDs(id <COItemGraph> aGraph);
