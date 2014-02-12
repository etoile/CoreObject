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
 * Protocol for a mutable item graph
 *
 * The object model is:
 * All objects must have a composite or non-composite relationship path to the root
 * (garbage-collected graph approach). This can be violated in the short term while
 * making a batch of changes.
 *
 * Garbage collection is not covered by this protocol.
 */
@protocol COItemGraph <NSObject>

- (ETUUID *) rootItemUUID;
/**
 * Returns immutable item
 */
- (COItem *) itemForUUID: (ETUUID *)aUUID;

- (NSArray *) itemUUIDs;
/**
 * Insert or updates the given items.
 * When combined with the receiver, all inner references should be resolved.
 * May broadcase a change notification, up to the subclass.
 */
- (void) insertOrUpdateItems: (NSArray *)items;

@end

/**
 * @group Storage Data Model
 * @abstract
 * An item graph is a mutable set of COItem objects, and a root item UUID, which
 * is the designated entry point to the object graph.
 *
 * COItemGraph is allowed to contain broken references (i.e. it can contain
 * COItems which have ETUUID references to items not in the COItemGraph, or
 * even be missing the COItem for the root item UUID) - this
 * is to allow COItemGraph to act as a simple delta mechanism, so you can
 * compute (COItemGraph + COItemGraph) = a new COItemGraph.
 */
@interface COItemGraph : NSObject <COItemGraph>
{
    ETUUID *rootItemUUID_;
    NSMutableDictionary *itemForUUID_;
}

+ (COItemGraph *)itemGraphWithItemsRootFirst: (NSArray*)items;

/**
 * N.B. items doesn't need to contain rootItemUUID
 */
- (id) initWithItemForUUID: (NSDictionary *) itemForUUID
              rootItemUUID: (ETUUID *)root;

/**
 * N.B. items doesn't need to contain rootItemUUID
 */
- (id) initWithItems: (NSArray *)items
        rootItemUUID: (ETUUID *)root;

- (id) initWithItemGraph: (id<COItemGraph>)aGraph;

@property (nonatomic, strong) ETUUID *rootItemUUID;

- (COMutableItem *) itemForUUID: (ETUUID *)aUUID;

- (NSArray *) itemUUIDs;

- (NSArray *) items;

- (void) insertOrUpdateItems: (NSArray *)items;

- (void) addItemGraph: (id<COItemGraph>)aGraph;

@end

/**
 * For debugging
 */
void COValidateItemGraph(id<COItemGraph> aGraph);

id COItemGraphToJSONPropertyList(id<COItemGraph> aGraph);
NSData *COItemGraphToJSONData(id<COItemGraph> aGraph);

COItemGraph *COItemGraphFromJSONPropertyLisy(id plist);
COItemGraph *COItemGraphFromJSONData(NSData *json);

BOOL COItemGraphEqualToItemGraph(id<COItemGraph> first, id<COItemGraph> second);

/**
 * If [aGraph rootItemUUID] is nil, returns the empty set
 */
NSSet *COItemGraphReachableUUIDs(id<COItemGraph> aGraph);
