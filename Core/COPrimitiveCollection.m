/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COPrimitiveCollection.h"
#import "COObject.h"
#import "COPath.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

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

static inline void COThrowExceptionIfOutOfBounds(COMutableArray *self, NSUInteger index, BOOL isInsertion)
{
	NSUInteger maxIndex = isInsertion ? self.count : self.count - 1;

	if (index > maxIndex)
	{
		[NSException raise: NSRangeException
		            format: @"Attempt to access index %lu out of bounds (%lu) for %@",
		                   (unsigned long)index, (unsigned long)self.count - 1, self];
	}
}

@implementation COMutableArray

@synthesize mutable = _mutable, backing = _backing;

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
	_deadIndexes = [NSMutableIndexSet new];
	
	_mutable = YES;
	for (NSUInteger i=0; i<count; i++)
	{
		[self addReference: objects[i]];
	}
	_mutable = NO;

	return self;
}

- (instancetype)initWithCapacity: (NSUInteger)capacity
{
	return [self init];
}

- (id)copyWithZone: (NSZone *)zone
{
	COMutableArray *newArray = [[self class] allocWithZone: zone];
	
	newArray->_backing = [_backing copyWithZone: zone];
	newArray->_deadIndexes = [_deadIndexes mutableCopyWithZone: zone];
	newArray->_mutable = _mutable;

	return newArray;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
	COMutableArray *newArray = [self copyWithZone: zone];
	newArray->_mutable = YES;
	return newArray;
}

- (id <NSFastEnumeration>)enumerableReferences
{
	return _backing;
}

- (id)referenceAtIndex: (NSUInteger)index
{
	return [_backing pointerAtIndex: index];
}

- (void)addReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_mutable);
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadIndexes addIndex: _backing.count];
	}
	[_backing addPointer: (__bridge void *)aReference];
}

- (void)replaceReferenceAtIndex: (NSUInteger)index withReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_mutable);
	if ([(id)[_backing pointerAtIndex: index] isKindOfClass: [COPath class]])
	{
		[_deadIndexes removeIndex: index];
	}
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadIndexes addIndex: index];
	}
	[_backing replacePointerAtIndex: index withPointer: (__bridge void *)aReference];
}

- (NSIndexSet *)aliveIndexes
{
	NSMutableIndexSet *indexes =
		[NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [_backing count])];
	[indexes removeIndexes: _deadIndexes];
	return indexes;
}

- (NSUInteger)count
{
	return [[self aliveIndexes] count];
}

- (NSUInteger)backingIndex: (NSUInteger)index
{
	__block NSUInteger backingIndex = NSNotFound;
	__block NSUInteger position = 0;
	[[self aliveIndexes] enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop)
	{
		if (position == index)
		{
			backingIndex = idx;
			*stop = YES;
		}
		position++;
	}];
	
	if (backingIndex == NSNotFound && position <= index)
	{
		backingIndex = _backing.count;
	}
 
	return backingIndex;
}

- (id)objectAtIndex: (NSUInteger)index
{
	COThrowExceptionIfOutOfBounds(self, index, NO);
	return [_backing pointerAtIndex: [self backingIndex: index]];
}

- (void)addObject: (id)anObject
{
	NSUInteger count = self.count;
	[self insertObject: anObject atIndex: (count > 0 ? count : 0)];
}

- (void)insertObject: (id)anObject atIndex: (NSUInteger)index
{
	COThrowExceptionIfNotMutable(_mutable);
	COThrowExceptionIfOutOfBounds(self, index, YES);
	
	NSUInteger backingIndex = [self backingIndex: index];

    // NSPointerArray on 10.7 doesn't allow inserting at the end using index == count, so
    // call addPointer in that case as a workaround.
    if (backingIndex == [_backing count])
    {
        [_backing addPointer: (__bridge void *)anObject];
    }
    else
	{
        [_backing insertPointer: (__bridge void *)anObject
						atIndex: backingIndex];
		[_deadIndexes shiftIndexesStartingAtIndex: backingIndex by: 1];
    }
}

- (void)removeLastObject
{
	NSUInteger count = self.count;

	if (count == 0)
		return;

	[self removeObjectAtIndex: count - 1];
}

- (void)removeObjectAtIndex: (NSUInteger)index
{
	COThrowExceptionIfNotMutable(_mutable);
	COThrowExceptionIfOutOfBounds(self, index, NO);

	NSUInteger backingIndex = [self backingIndex: index];
	/* According to Apple doc, "A left shift deletes the indexes in a range the 
	   length of delta preceding startIndex from the set", so we must alter  
	   this behavior to avoid losing indexes.
	   See also http://ootips.org/yonat/workaround-for-bug-in-nsindexset-shiftindexesstartingatindex/ */
	BOOL isPreviousIndexDead = [_deadIndexes containsIndex: backingIndex - 1];

	[_backing removePointerAtIndex: backingIndex];
	[_deadIndexes shiftIndexesStartingAtIndex: backingIndex by: -1];
	if (isPreviousIndexDead)
	{
		[_deadIndexes addIndex: backingIndex - 1];
	}
	
}

- (void)replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_mutable);
	COThrowExceptionIfOutOfBounds(self, index, NO);
	[_backing replacePointerAtIndex: [self backingIndex: index]
	                    withPointer: (__bridge void *)anObject];
}

// TODO: Compute a diff between the receiver objects and the ones in argument,
// then apply insertion, move and removal operations to the receiver derived
// from the diff. In this way, the dead references would shifted around more properly.
- (void)setArray: (NSArray *)liveObjects
{
	COThrowExceptionIfNotMutable(_mutable);

	NSArray *deadReferences = [_backing.allObjects objectsAtIndexes: _deadIndexes];

	_backing = [self makeBacking];
	_deadIndexes = [NSMutableIndexSet new];

	NSArray *validLiveObjects = (liveObjects != nil ? liveObjects : [NSArray new]);

	for (id reference in [validLiveObjects arrayByAddingObjectsFromArray: deadReferences])
	{
		[self addReference: reference];
	}
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

- (instancetype)initWithObjects: (const id [])objects count: (NSUInteger)count
{
	self = [super initWithObjects: objects count: count];
	if (self == nil)
		return nil;
	
	_deadReferences = [NSMutableSet new];
	return self;
}

- (id)copyWithZone: (NSZone *)zone
{
	COUnsafeRetainedMutableArray *newArray = [super copyWithZone: zone];
	newArray->_deadReferences = [_deadReferences mutableCopyWithZone: zone];
	return newArray;
}

- (void)addReference: (id)aReference
{
	[super addReference: aReference];
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadReferences addObject: aReference];
	}
}

- (void)replaceReferenceAtIndex: (NSUInteger)index withReference: (id)aReference
{
	[super replaceReferenceAtIndex: index withReference: aReference];
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadReferences addObject: aReference];
	}
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
	_deadReferences = [NSHashTable new];

	_mutable = YES;
	for (NSUInteger i=0; i<count; i++)
	{
		[self addReference: objects[i]];
	}
	_mutable = NO;

	return self;
}
- (instancetype)initWithCapacity: (NSUInteger)numItems
{
	return [self init];
}

- (id)copyWithZone: (NSZone *)zone
{
	COMutableSet *newSet = [[self class] allocWithZone: zone];
	
	newSet->_backing = [_backing copyWithZone: zone];
	newSet->_deadReferences = [_deadReferences copyWithZone: zone];
	newSet->_mutable = _mutable;
	
	return newSet;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
	COMutableSet *newSet = [self copyWithZone: zone];
	newSet->_mutable = YES;
	return newSet;
}

- (id <NSFastEnumeration>)enumerableReferences
{
	return _backing;
}

- (void)addReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_mutable);
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadReferences addObject: aReference];
	}
	[_backing addObject: aReference];
}

- (void)removeReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_mutable);
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadReferences removeObject: aReference];
	}
	[_backing removeObject: aReference];
}

- (BOOL)containsReference: (id)aReference
{
	return [_backing member: aReference] != nil;
}

- (NSHashTable *)aliveObjects
{
	NSHashTable *aliveObjects = [_backing mutableCopy];
	[aliveObjects minusHashTable: _deadReferences];
	return aliveObjects;
}

- (NSUInteger)count
{
	return [_backing count] - [_deadReferences count];
}

- (id)member: (id)anObject
{
	return [_deadReferences member: anObject] == nil ? [_backing member: anObject] : nil;
}

- (NSUInteger)countByEnumeratingWithState: (NSFastEnumerationState *)state 
                                  objects: (__unsafe_unretained id[])stackbuf 
                                    count: (NSUInteger)len
{
	// TODO: Don't recreate aliveObjects on every invocation
	return [[self aliveObjects] countByEnumeratingWithState: state objects: stackbuf count: len];
}

- (NSEnumerator *)objectEnumerator
{
	return [[self aliveObjects] objectEnumerator];
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
	_backing = [[NSMutableDictionary alloc] initWithCapacity: count];
	_deadKeys = [NSMutableSet new];
	
	_mutable = YES;
	for (NSUInteger i=0; i<count; i++)
	{
		[self setReference: objects[i] forKey: keys[i]];
	}
	_mutable = NO;

	return self;
}

- (instancetype)initWithCapacity: (NSUInteger)aCount
{
	return [self init];
}

- (id)copyWithZone: (NSZone *)zone
{
	COMutableDictionary *newDictionary = [[self class] allocWithZone: zone];
	
	newDictionary->_backing = [_backing copyWithZone: zone];
	newDictionary->_deadKeys = [_deadKeys copyWithZone: zone];
	newDictionary->_mutable = _mutable;
	
	return newDictionary;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
	COMutableDictionary *newDictionary = [self copyWithZone: zone];
	newDictionary->_mutable = YES;
	return newDictionary;
}

- (id <NSFastEnumeration>)enumerableReferences
{
	return [_backing objectEnumerator];
}

- (void)setReference: (id)aReference forKey: (id<NSCopying>)aKey
{
	COThrowExceptionIfNotMutable(_mutable);
	if ([aReference isKindOfClass: [COPath class]])
	{
		[_deadKeys addObject: aKey];
	}
	if ([_backing[aKey] isKindOfClass: [COPath class]])
	{
		[_deadKeys removeObject: aKey];
	}
	_backing[aKey] = aReference;
}

- (NSDictionary *)aliveEntries
{
	NSMutableDictionary *aliveEntries = [_backing mutableCopy];
	[_backing removeObjectsForKeys: [_deadKeys allObjects]];
	return aliveEntries;
}

- (NSUInteger)count
{
	return [_backing count] - [_deadKeys count];
}

- (id)objectForKey: (id)key
{
	return ![_deadKeys containsObject: key] ? [_backing objectForKey: key] : nil;
}

- (NSEnumerator *)objectEnumerator
{
	return [[self aliveEntries] objectEnumerator];
}

- (NSEnumerator *)keyEnumerator
{
	return [[self aliveEntries] keyEnumerator];
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
