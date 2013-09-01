#import "COObjectGraphContext.h"

@interface COObjectGraphContext ()

/**
 * @taskunit Framework Private
 */

/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Sets the branch owning the object graph.
 */
- (void)setBranch: (COBranch *)aBranch;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Returns the inner object bound to the given UUID in the object graph.
 *
 * If the object is not loaded yet and a serialized representation exists in
 * the store for the UUID, returns a new instance.
 *
 * If there is no committed object for the given UUID in the store, returns nil.
 *
 * This method can resolve entity descriptions during an item graph
 * deserialization without accessing the store.
 */
- (id)objectReferenceWithUUID: (ETUUID *)aUUID;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Puts the object among the loaded objects.
 */
- (void)registerObject: (COObject *)object isNew: (BOOL)inserted;
/**
 * This method is only exposed to be used internally by CoreObject.
 *
 * Tells the object graph context a property value has changed in a COObject
 * instance.
 */
- (void)markObjectAsUpdated: (COObject *)obj forProperty: (NSString *)aProperty;


/**
 * This method is deprecated and private.
 */
- (id)insertObjectWithEntityName: (NSString *)aFullName
                            UUID: (ETUUID *)aUUID;

@end
