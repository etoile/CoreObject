/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COObject, COPath;

@interface COWeakRef : NSObject
{
	@public
	__weak COObject *_object;
}

- (instancetype)initWithObject: (COObject *)anObject;

@end


@protocol COPrimitiveCollection <NSObject>
@property (nonatomic, getter=isMutable) BOOL mutable;
@end

@interface COMutableSet : NSMutableSet <COPrimitiveCollection>
{
	@public
	BOOL _mutable;
	NSHashTable *_backing;
	NSHashTable *_deadReferences;
}
- (void)addReference: (id)aReference;
- (void)removeReference: (id)aReference;
- (BOOL)containsReference: (id)aReference;
@end

@interface COMutableArray : NSMutableArray <COPrimitiveCollection>
{
@public
	BOOL _mutable;
	NSPointerArray *_backing;
	NSMutableIndexSet *_deadIndexes;
}
- (id)referenceAtIndex: (NSUInteger)index;
- (void)addReference: (id)aReference;
- (void)replaceReferenceAtIndex: (NSUInteger)index withReference: (id)aReference;
@end

@interface COUnsafeRetainedMutableSet : COMutableSet
@end

@interface COUnsafeRetainedMutableArray : COMutableArray
{
	// TODO: Replace with custom acquire/relinquish functions to retain/release
	// COPath references as necessary
	NSMutableSet *_deadReferences;
}
@end

@interface COMutableDictionary : NSMutableDictionary <COPrimitiveCollection>
{
	@public
	BOOL _mutable;
	NSMutableDictionary *_backing;
	NSMutableSet *_deadKeys;
}
- (void)setReference: (id)aReference forKey: (id <NSCopying>)aKey;
@end
