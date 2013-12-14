#import "COWeakMutableSet.h"

@implementation COWeakMutableSet

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _hashTable = [[NSHashTable alloc] initWithOptions: NSHashTableWeakMemory capacity: 16];
    }
    return self;
}

- (void)dealloc
{
    [_hashTable release];
    [super dealloc];
}

- (NSUInteger) count
{
    return NSCountHashTable(_hashTable);
}

- (id) member: (id)anObject
{
    return NSHashGet(_hashTable, anObject);
}

- (NSEnumerator *) objectEnumerator
{
    return [_hashTable objectEnumerator];
}

- (void) addObject: (id)anObject
{
    NSHashInsert(_hashTable, anObject);
}

- (void) removeObject: (id)anObject
{
    NSHashRemove(_hashTable, anObject);
}

@end
