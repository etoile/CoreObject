#import <CodeObject/COObjectGraphContext.h>

@interface COObjectGraphContext (Debugging)

/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (NSArray *)insertedObjects;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (NSArray *)updatedObjects;
/**
 * This method is only exposed to be used internally by CoreObject.
 */
- (NSArray *)changedObjects;

@end
