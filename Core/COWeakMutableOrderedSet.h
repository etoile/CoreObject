#import <Foundation/Foundation.h>

@interface COWeakMutableOrderedSet : NSMutableOrderedSet
{
    /**
     * Maps objects in the ordered set to their index + 1
     */
    NSMapTable *_objectToIndex;
    NSPointerArray *_indexToObject;
}

- (NSUInteger) count;
- (id) objectAtIndex: (NSUInteger)anIndex;
- (NSUInteger) indexOfObject: (id)anObject;

- (void) insertObject: (id)anObject atIndex: (NSUInteger)anIndex;
- (void) removeObjectAtIndex: (NSUInteger)anIndex;
- (void) replaceObjectAtIndex: (NSUInteger)anIndex withObject: (id)anObject;

@end
