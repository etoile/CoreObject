#import "COWeakMutableOrderedSet.h"

@implementation COWeakMutableOrderedSet

- (id) init
{
    self = [super init];
    if (self != nil)
    {
        _objectToIndex = [[NSMapTable alloc] initWithKeyOptions: NSMapTableZeroingWeakMemory
                                                   valueOptions: NSPointerFunctionsIntegerPersonality
                                                       capacity: 16];
        
        _indexToObject = [[NSPointerArray alloc] initWithOptions: NSPointerFunctionsZeroingWeakMemory];
        
    }
    return self;
}

- (NSUInteger) count
{
    return [_indexToObject count];
}

- (id) objectAtIndex: (NSUInteger)anIndex
{
    return [_indexToObject pointerAtIndex: anIndex];
}

- (NSUInteger) indexOfObject: (id)anObject
{
    void *value = NSMapGet(_objectToIndex, (__bridge void *)anObject);
    
    if (value == NULL)
    {
        return NSNotFound;
    }
    
    return ((uintptr_t)value) - 1;
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)anIndex
{
    const NSUInteger count = [_indexToObject count];
    
    // 1. Shift objects at index anIndex and greater up by 1
    
    for (NSUInteger i = anIndex; i < count; i++)
    {
        id object = [_indexToObject pointerAtIndex: i];
        NSMapRemove(_objectToIndex, (__bridge void *)object);
        NSMapInsert(_objectToIndex, (__bridge void *)object, i + 2);
    }
    
    // 2. Insert new value
    
    NSMapInsert(_objectToIndex, (__bridge void *)anObject, anIndex + 1);
    [_indexToObject insertPointer: (__bridge void *)anObject atIndex: anIndex];
}

- (void) removeObjectAtIndex: (NSUInteger)anIndex
{
    const NSUInteger count = [_indexToObject count];
    
    // 1. Remove object at index anIndex from _objectToIndex
    
    NSMapRemove(_objectToIndex, [_indexToObject pointerAtIndex: anIndex]);
    
    // 2. Shift objects at index anIndex + 1 and greater down by 1
    
    for (NSUInteger i = anIndex + 1; i < count; i++)
    {
        id object = [_indexToObject pointerAtIndex: i];
        NSMapRemove(_objectToIndex, (__bridge void *)object);
        NSMapInsert(_objectToIndex, (__bridge void *)object, i);
    }
    
    // 3. Update _indexToObject
    
    [_indexToObject removePointerAtIndex: anIndex];
}

- (void) replaceObjectAtIndex: (NSUInteger)anIndex withObject: (id)anObject
{
    id oldObject = [_indexToObject pointerAtIndex: anIndex];
    
    NSMapRemove(_objectToIndex, (__bridge void *)oldObject);
    NSMapInsert(_objectToIndex, (__bridge void *)anObject, anIndex + 1);
    
    [_indexToObject replacePointerAtIndex: anIndex withPointer: (__bridge void *)anObject];
}

@end
