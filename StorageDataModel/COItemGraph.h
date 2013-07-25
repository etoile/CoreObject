#import <Foundation/Foundation.h>

@class ETUUID;
@class COItem, COMutableItem;

/**
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
 * Insert or update an item
 */
- (void) addItem: (COItem *)anItem;

@end

/**
 * An item tree is just a mutable set of COItem objects along
 * with the UUID of the root object.
 *
 * However, there is no guarantee that the items form a complete tree,
 * or even that the item for the root UUID is in the set of items.
 *
 * The intended use for COItemTree is as a really simple
 * delta mechanism, so you can compute (COItemTree + COItemTree) = a new COItemTree
 */
@interface COItemGraph : NSObject <COItemGraph>
{
    ETUUID *rootItemUUID_;
    NSMutableDictionary *itemForUUID_;
}

+ (COItemGraph *)treeWithItemsRootFirst: (NSArray*)items;

- (id) initWithItemForUUID: (NSDictionary *) itemForUUID
              rootItemUUID: (ETUUID *)root;
- (id) initWithItems: (NSArray *)items
        rootItemUUID: (ETUUID *)root;

- (ETUUID *) rootItemUUID;
- (COMutableItem *) itemForUUID: (ETUUID *)aUUID;

- (NSArray *) itemUUIDs;

- (void) addItem: (COItem *)anItem;

@end
