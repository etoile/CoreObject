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

static inline BOOL COIsTombstone(NSObject *obj)
{
    return [obj isKindOfClass: [COPath class]];
}

static inline void COThrowExceptionIfNotMutable(BOOL permanent, int temp)
{
	if (!permanent && temp == 0)
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

@synthesize backing = _backing;

- (void) beginMutation
{
	_temporaryMutable++;
}

- (void) endMutation
{
	_temporaryMutable--;
	if (_temporaryMutable < 0)
	{
		/*
		 * Currently, we need to "eat" extra -endTemporaryModification calls because
		 * during deserialization, we create a new COPrimitiveCollection, add it to the
		 * variable storage, and then -didChangeValueForProperty: will make a
		 * -endTemporaryModification call. Since the collection was created after the
		 * -willChangeValueForProperty:, it didn't get the matching
		 * beginTemporaryModification call.
		 */
		_temporaryMutable = 0;
	}
}

- (BOOL) isMutable
{
	return _permanentlyMutable || _temporaryMutable > 0;
}

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
	_externalIndexToBackingIndex = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];
	
	[self beginMutation];
	for (NSUInteger i=0; i<count; i++)
	{
		[self addReference: objects[i]];
	}
	[self endMutation];

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
	newArray->_externalIndexToBackingIndex = [_externalIndexToBackingIndex copyWithZone: zone];
	newArray->_permanentlyMutable = _permanentlyMutable;
	newArray->_temporaryMutable = _temporaryMutable;

	return newArray;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
	COMutableArray *newArray = [self copyWithZone: zone];
	newArray->_permanentlyMutable = YES;
	newArray->_temporaryMutable = 0;
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
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	if (!COIsTombstone(aReference))
	{
		[_externalIndexToBackingIndex addPointer: (void *)_backing.count];
	}
	[_backing addPointer: (__bridge void *)aReference];
}

- (NSUInteger)firstExternalIndexGreaterThanOrEqualToBackingIndex: (NSUInteger)index
{
	const NSUInteger externalCount = _externalIndexToBackingIndex.count;
	for (NSUInteger externalI = 0; externalI < externalCount; externalI++)
	{
		const NSUInteger backingI  = (NSUInteger)[_externalIndexToBackingIndex pointerAtIndex: externalI];
		if (backingI >= index)
		{
			return externalI;
		}
	}
	return NSNotFound;
}

- (void)shiftBackingIndicesGreaterThanOrEqualTo: (NSUInteger)index by: (NSInteger)delta
{
	const NSUInteger externalCount = _externalIndexToBackingIndex.count;
	for (NSUInteger i = 0; i < externalCount; i++)
	{
		const NSUInteger backingI  = (NSUInteger)[_externalIndexToBackingIndex pointerAtIndex: i];
		if (backingI >= index)
		{
			const NSUInteger shifted = backingI + delta;
			[_externalIndexToBackingIndex replacePointerAtIndex: i
													withPointer: (void *)shifted];
		}
	}
}

- (void)replaceReferenceAtIndex: (NSUInteger)index withReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	
	const BOOL wasTombstone = COIsTombstone((id)[_backing pointerAtIndex: index]);
	const BOOL willBeTombstone = COIsTombstone(aReference);
	
	if (!wasTombstone && willBeTombstone)
	{
		NSUInteger externalI = [self firstExternalIndexGreaterThanOrEqualToBackingIndex: index];
		
		[_externalIndexToBackingIndex removePointerAtIndex: externalI];
	}
	else if (wasTombstone && !willBeTombstone)
	{
		NSUInteger externalI = [self firstExternalIndexGreaterThanOrEqualToBackingIndex: index];
		if (externalI == NSNotFound)
		{
			// inserting at the end
			[_externalIndexToBackingIndex addPointer: (void *)index];
		}
		else
		{
			[_externalIndexToBackingIndex insertPointer: (void *)index
												atIndex: externalI];
		}
	}

	[_backing replacePointerAtIndex: index withPointer: (__bridge void *)aReference];
}

- (NSUInteger)count
{
	return _externalIndexToBackingIndex.count;
}

- (NSUInteger)backingIndex: (NSUInteger)index
{
	return (NSUInteger)[_externalIndexToBackingIndex pointerAtIndex: index];
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
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	COThrowExceptionIfOutOfBounds(self, index, YES);
	
	ETAssert(!COIsTombstone(anObject));
	
    // NSPointerArray on 10.7 doesn't allow inserting at the end using index == count, so
    // call addPointer in that case as a workaround.
    if (index == _externalIndexToBackingIndex.count)
    {
		// insert at end
		[_externalIndexToBackingIndex addPointer: (void *)_backing.count];
		[_backing addPointer: (__bridge void *)anObject];
    }
    else
	{
		// insert in the beginning or middle
		NSUInteger backingIndex = [self backingIndex: index];

		[self shiftBackingIndicesGreaterThanOrEqualTo: backingIndex by: 1];
		
		[_externalIndexToBackingIndex insertPointer: (void *)backingIndex
											atIndex: index];
        [_backing insertPointer: (__bridge void *)anObject
						atIndex: backingIndex];
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
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	COThrowExceptionIfOutOfBounds(self, index, NO);

	NSUInteger backingIndex = [self backingIndex: index];
	[_backing removePointerAtIndex: backingIndex];
	[_externalIndexToBackingIndex removePointerAtIndex: index];
	
	[self shiftBackingIndicesGreaterThanOrEqualTo: backingIndex by: -1];
}

- (void)replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	COThrowExceptionIfOutOfBounds(self, index, NO);
	ETAssert(!COIsTombstone(anObject));
	[_backing replacePointerAtIndex: [self backingIndex: index]
	                    withPointer: (__bridge void *)anObject];
}

// TODO: Compute a diff between the receiver objects and the ones in argument,
// then apply insertion, move and removal operations to the receiver derived
// from the diff. In this way, the dead references would shifted around more properly.
- (void)setArray: (NSArray *)liveObjects
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);

	NSArray *deadReferences = [_backing.allObjects filteredCollectionWithBlock: ^(id obj) {
		return COIsTombstone(obj);
	}];
							   
	[_backing setCount: 0];
	[_externalIndexToBackingIndex setCount: 0];

	NSArray *validLiveObjects = (liveObjects != nil ? liveObjects : [NSArray new]);

	for (id reference in [validLiveObjects arrayByAddingObjectsFromArray: deadReferences])
	{
		[self addReference: reference];
	}
}

// NOTE: For any additional mutation methods added, ensure they are overridden
// in COUnsafeRetainedMutableArray to enforce no duplicates

@end


@implementation COMutableArray (TestPrimitiveCollection)

- (NSIndexSet *)deadIndexes
{
	return [self.allReferences indexesOfObjectsPassingTest: ^(id obj, NSUInteger idx, BOOL *stop) {
		return [obj isKindOfClass: [COPath class]];
	}];
}

- (NSArray *)deadReferences
{
	return [self.allReferences objectsAtIndexes: [self deadIndexes]];
}

- (NSArray *)allReferences
{
	NSMutableArray *results = [NSMutableArray new];
	for (id ref in self.enumerableReferences) {
		[results addObject: ref];
	}
	return results;
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

- (NSHashTable *) makeBackingHashTable
{
#if TARGET_OS_IPHONE
	return [NSHashTable weakObjectsHashTable];
#else
	return [NSHashTable hashTableWithWeakObjects];
#endif
}

- (instancetype)initWithObjects: (const id [])objects count: (NSUInteger)count
{
	self = [super initWithObjects: objects count: count];
	if (self == nil)
		return nil;
	
	_deadReferences = [NSMutableSet new];
	_backingHashTable = [self makeBackingHashTable];
	
	return self;
}

- (id)copyWithZone: (NSZone *)zone
{
	COUnsafeRetainedMutableArray *newArray = [super copyWithZone: zone];
	newArray->_deadReferences = [_deadReferences mutableCopyWithZone: zone];
	newArray->_backingHashTable = [_backingHashTable copyWithZone: zone];
	return newArray;
}

- (BOOL)checkPresentAndAddToHashTable: (id)anObject
{
	if ([_backingHashTable containsObject: anObject])
	{
		return YES;
	}
	else
	{
		[_backingHashTable addObject: anObject];
		return NO;
	}
}

- (void)addReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);

	// discard duplicates
	if ([self checkPresentAndAddToHashTable: aReference])
	{
		return;
	}
	
	[super addReference: aReference];
	if (COIsTombstone(aReference))
	{
		[_deadReferences addObject: aReference];
	}
}

- (void)replaceReferenceAtIndex: (NSUInteger)index withReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);

	// discard duplicates
	if ([self checkPresentAndAddToHashTable: aReference])
	{
		return;
	}

	// remove old value from hash table
	id oldValue = [_backing pointerAtIndex: index];
	[_backingHashTable removeObject: oldValue];
	if (COIsTombstone(oldValue))
	{
		[_deadReferences removeObject: oldValue];
	}

	[super replaceReferenceAtIndex: index withReference: aReference];
	if (COIsTombstone(aReference))
	{
		[_deadReferences addObject: aReference];
	}
}

- (void)insertObject: (id)anObject atIndex: (NSUInteger)index
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);

	// discard duplicates
	if ([self checkPresentAndAddToHashTable: anObject])
	{
		return;
	}
	
	[super insertObject: anObject atIndex: index];
}

- (void)removeObjectAtIndex: (NSUInteger)index
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	
	// remove old value from hash table
	[_backingHashTable removeObject: [self objectAtIndex: index]];
	
	[super removeObjectAtIndex: index];
}

- (void)replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	
	// discard duplicates
	if ([self checkPresentAndAddToHashTable: anObject])
	{
		return;
	}
	
	// remove old value from hash table
	[_backingHashTable removeObject: [self objectAtIndex: index]];
	
	[super replaceObjectAtIndex: index withObject: anObject];
}

- (void)setArray: (NSArray *)liveObjects
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);

	// remove old values from hash table
	[_backingHashTable removeAllObjects];
	
	[super setArray: liveObjects];
}

@end


@implementation COMutableSet

- (void) beginMutation
{
	_temporaryMutable++;
}

- (void) endMutation
{
	_temporaryMutable--;
	if (_temporaryMutable < 0)
	{
		_temporaryMutable = 0;
	}
}

- (BOOL) isMutable
{
	return _permanentlyMutable || _temporaryMutable > 0;
}

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

	[self beginMutation];
	for (NSUInteger i=0; i<count; i++)
	{
		[self addReference: objects[i]];
	}
	[self endMutation];

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
	newSet->_permanentlyMutable = _permanentlyMutable;
	newSet->_temporaryMutable = _temporaryMutable;
	
	return newSet;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
	COMutableSet *newSet = [self copyWithZone: zone];
	newSet->_permanentlyMutable = YES;
	newSet->_temporaryMutable = 0;
	return newSet;
}

- (id <NSFastEnumeration>)enumerableReferences
{
	return _backing;
}

- (void)addReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	[_backing addObject: aReference];
	if (COIsTombstone(aReference))
	{
		[_deadReferences addObject: aReference];
	}
}

- (void)removeReference: (id)aReference
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	[_backing removeObject: aReference];
	if (COIsTombstone(aReference))
	{
		[_deadReferences removeObject: aReference];
	}
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
	return _backing.count - _deadReferences.count;
}

- (id)member: (id)anObject
{
	return [_deadReferences member: anObject] == nil ? [_backing member: anObject] : nil;
}

- (NSEnumerator *)objectEnumerator
{
	return [[self aliveObjects] objectEnumerator];
}

- (void)addObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	ETAssert(!COIsTombstone(anObject));
		
	[_backing addObject: anObject];
}

- (void)removeObject: (id)anObject
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	ETAssert(!COIsTombstone(anObject));
	
	[_backing removeObject: anObject];
}

- (NSArray *)deadReferencesArray
{
	return [_deadReferences allObjects];
}

@end


@implementation COMutableSet (TestPrimitiveCollection)

- (NSSet *)deadReferences
{
	return [self.allReferences objectsPassingTest:^(id obj, BOOL *stop) {
		return [obj isKindOfClass: [COPath class]];
	}];
}

- (NSSet *)allReferences
{
	NSMutableSet *results = [NSMutableSet new];
	for (id ref in self.enumerableReferences) {
		[results addObject: ref];
	}
	return results;
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

- (void) beginMutation
{
	_temporaryMutable++;
}

- (void) endMutation
{
	_temporaryMutable--;
	if (_temporaryMutable < 0)
	{
		_temporaryMutable = 0;
	}
}

- (BOOL) isMutable
{
	return _permanentlyMutable || _temporaryMutable > 0;
}

- (instancetype)init
{
	return [self initWithObjects: NULL forKeys: NULL count: 0];
}

- (instancetype)initWithObjects: (const id[])objects forKeys: (const id <NSCopying>[])keys count: (NSUInteger)count
{
	SUPERINIT;
	_backing = [[NSMutableDictionary alloc] initWithCapacity: count];
	_deadKeys = [NSMutableSet new];
	
	[self beginMutation];
	for (NSUInteger i=0; i<count; i++)
	{
		[self setReference: objects[i] forKey: keys[i]];
	}
	[self endMutation];

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
	newDictionary->_permanentlyMutable = _permanentlyMutable;
	newDictionary->_temporaryMutable = _temporaryMutable;
	
	return newDictionary;
}

- (id)mutableCopyWithZone: (NSZone *)zone
{
	COMutableDictionary *newDictionary = [self copyWithZone: zone];
	newDictionary->_permanentlyMutable = YES;
	newDictionary->_temporaryMutable = 0;
	return newDictionary;
}

- (id <NSFastEnumeration>)enumerableReferences
{
	return [_backing objectEnumerator];
}

- (void)setReference: (id)aReference forKey: (id<NSCopying>)aKey
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	if (COIsTombstone(aReference))
	{
		[_deadKeys addObject: aKey];
	}
	if (COIsTombstone(_backing[aKey]))
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
	return _backing.count - _deadKeys.count;
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
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	[_backing removeObjectForKey: aKey];
}

- (void)setObject: (id)anObject forKey: (id <NSCopying>)aKey
{
	COThrowExceptionIfNotMutable(_permanentlyMutable, _temporaryMutable);
	[_backing setObject: anObject forKey: aKey];
}

@end
