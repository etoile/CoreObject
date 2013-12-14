#import <Foundation/Foundation.h>

@interface COWeakMutableSet : NSMutableSet
{
    NSHashTable *_hashTable;
}

- (NSUInteger) count;
- (id) member: (id)anObject;
- (NSEnumerator *) objectEnumerator;
- (void) addObject: (id)anObject;
- (void) removeObject: (id)anObject;

@end
