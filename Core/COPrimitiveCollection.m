/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COPrimitiveCollection.h"
#import "COObject.h"

@implementation COWeakRef

- (instancetype) initWithObject: (COObject *)anObject
{
	SUPERINIT;
	_object = anObject;
	return self;
}

@end


static inline void COThrowExceptionIfNotMutable(BOOL mutable)
{
	if (!mutable)
	{
		[NSException raise: NSGenericException
		            format: @"Attempted to modify an immutable collection"];
	}
}


@implementation COMutableArray

@synthesize mutable = _mutable;

- (NSPointerArray *) makeBacking
{
#if TARGET_OS_IPHONE
	return [NSPointerArray strongObjectsPointerArray];
#else
	return [NSPointerArray pointerArrayWithStrongObjects];
#endif
}

- (instancetype)init
{
	return [self initWithObjects: NULL count: 0];
}

- (instancetype)initWithObjects: (const id [])objects count: (NSUInteger)count
{
	SUPERINIT;
	_backing = [self makeBacking];
	for (NSUInteger i=0; i<count; i++)
	{
		[_backing addPointer: (__bridge void *)objects[i]];
	}
	return self;
}

- (instancetype)initWithCapacity: (NSUInteger)capacity
{
	return [self init];
}

- (NSUInteger)count
{
	return [_backing count];
}

- (id)objectAtIndex: (NSUInteger)index
{
	return [_backing pointerAtIndex: index];
}

- (void)addObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing addPointer: (__bridge void *)anObject];
}

- (void)insertObject: (id)anObject atIndex: (NSUInteger)index
{
	COThrowExceptionIfNotMutable(_mutable);
	
    // NSPointerArray on 10.7 doesn't allow inserting at the end using index == count, so
    // call addPointer in that case as a workaround.
    if (index == [_backing count])
    {
        [_backing addPointer: (__bridge void *)anObject];
    }
    else
    {
        [_backing insertPointer: (__bridge void *)anObject atIndex: index];
    }
}

- (void)removeLastObject
{
	COThrowExceptionIfNotMutable(_mutable);
	[self removeObjectAtIndex: [self count] - 1];
}

- (void)removeObjectAtIndex: (NSUInteger)index
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing removePointerAtIndex: index];
}

- (void)replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing replacePointerAtIndex: index withPointer: (__bridge void *)anObject];
}

@end

@implementation COUnsafeRetainedMutableArray

- (NSPointerArray *) makeBacking
{
#if TARGET_OS_IPHONE
	return [NSPointerArray weakObjectsPointerArray];
#else
	return [NSPointerArray pointerArrayWithWeakObjects];
#endif
}

@end


@implementation COMutableSet

@synthesize mutable = _mutable;

- (NSHashTable *) makeBacking
{
	return [[NSHashTable alloc] init];
}

- (instancetype)init
{
	return [self initWithObjects: NULL count: 0];
}

- (instancetype)initWithObjects: (const id[])objects count: (NSUInteger)count
{
	SUPERINIT;
	_backing = [self makeBacking];
	for (NSUInteger i=0; i<count; i++)
	{
		[_backing addObject: objects[i]];
	}
	return self;
}
- (instancetype)initWithCapacity: (NSUInteger)numItems
{
	return [self init];
}

- (NSUInteger)count
{
	return [_backing count];
}

- (id)member: (id)anObject
{
	return [_backing member: anObject];
}

- (NSUInteger)countByEnumeratingWithState: (NSFastEnumerationState *)state 
                                  objects: (__unsafe_unretained id[])stackbuf 
                                    count: (NSUInteger)len
{
	return [_backing countByEnumeratingWithState: state objects: stackbuf count: len];
}

- (NSEnumerator *)objectEnumerator
{
	return [_backing objectEnumerator];
}

- (void)addObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing addObject: anObject];
}

- (void)removeObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing removeObject: anObject];
}

@end

@implementation COUnsafeRetainedMutableSet

- (NSHashTable *) makeBacking
{
#if TARGET_OS_IPHONE
	return [NSHashTable weakObjectsHashTable];
#else
	return [NSHashTable hashTableWithWeakObjects];
#endif
}

@end


@implementation COMutableDictionary

@synthesize mutable = _mutable;

- (instancetype)init
{
	return [self initWithObjects: NULL forKeys: NULL count: 0];
}

- (instancetype)initWithObjects: (const id[])objects forKeys: (const id <NSCopying>[])keys count: (NSUInteger)count
{
	SUPERINIT;
	_backing = [[NSMutableDictionary alloc] initWithObjects: objects forKeys: keys count: count];
	return self;
}

- (instancetype)initWithCapacity: (NSUInteger)aCount
{
	return [self init];
}

- (NSUInteger)count
{
	return [_backing count];
}

- (id)objectForKey: (id)key
{
	return [_backing objectForKey: key];
}

- (NSEnumerator *)objectEnumerator
{
	return [_backing objectEnumerator];
}

- (NSEnumerator *)keyEnumerator
{
	return [_backing keyEnumerator];
}

- (void)removeObjectForKey: (id)aKey
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing removeObjectForKey: aKey];
}

- (void)setObject: (id)anObject forKey: (id <NSCopying>)aKey
{
	COThrowExceptionIfNotMutable(_mutable);
	[_backing setObject: anObject forKey: aKey];
}

@end
