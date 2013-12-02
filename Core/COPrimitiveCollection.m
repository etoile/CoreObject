/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  Modified BSD  (see COPYING)
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

@implementation COUnsafeRetainedMutableArray

- (instancetype)init
{
	return [self initWithObjects: NULL count: 0];
}

- (instancetype)initWithObjects: (const id [])objects count: (NSUInteger)count
{
	SUPERINIT;
	_backing = [NSPointerArray pointerArrayWithWeakObjects];
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


@implementation COUnsafeRetainedMutableSet

- (instancetype)init
{
	return [self initWithObjects: NULL count: 0];
}

- (instancetype)initWithObjects: (const id[])objects count: (NSUInteger)count
{
	SUPERINIT;
	_backing = [NSHashTable hashTableWithWeakObjects];
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


@implementation COMutableDictionary

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


@implementation NSObject (COPrimitiveCollection)

+ (Class)coreObjectClass
{
	return Nil;
}

- (id)mutableCoreObjectCopy
{
	return [self mutableCopy];
}

@end

@implementation NSArray (COPrimitiveCollection)

+ (Class)coreObjectClass
{
	return [COUnsafeRetainedMutableArray class];
}

- (id)mutableCoreObjectCopy
{
	return [[[[self class] coreObjectClass] alloc] initWithArray: self];
}

@end

@implementation NSSet (COPrimitiveCollection)

+ (Class)coreObjectClass
{
	return [COUnsafeRetainedMutableSet class];
}

- (id)mutableCoreObjectCopy
{
	return [[[[self class] coreObjectClass] alloc] initWithSet: self];
}

@end

@implementation NSDictionary (COPrimitiveCollection)

+ (Class)coreObjectClass
{
	return [COMutableDictionary class];
}

- (id)mutableCoreObjectCopy
{
	return [[[[self class] coreObjectClass] alloc] initWithDictionary: self];
}

@end
