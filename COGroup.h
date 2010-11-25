#import "COObject.h"

/**
 * COGroup is a COObject subclass which has an ordered, strong container
 * (contained objects can only be in one COGroup).
 */
@interface COGroup : COObject <ETCollection, ETCollectionMutation>
{
}

- (BOOL) isOrdered;
- (BOOL) isEmpty;
- (id) content;
- (NSArray *) contentArray;

- (void) addObject: (id)object;
- (void) insertObject: (id)object atIndex: (NSUInteger)index;
- (void) removeObject: (id)object;
- (void) removeObject: (id)object atIndex: (NSUInteger)index;

@end
