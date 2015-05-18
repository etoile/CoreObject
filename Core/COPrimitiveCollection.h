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
	NSHashTable *_deadObjects;
}
- (void)addDeadPath: (COPath *)aPath;
@end

@interface COMutableArray : NSMutableArray <COPrimitiveCollection>
{
@public
	BOOL _mutable;
	NSPointerArray *_backing;
	NSMutableIndexSet *_deadIndexes;
}
- (void)addDeadPath: (COPath *)aPath;
@end

@interface COUnsafeRetainedMutableSet : COMutableSet
@end

@interface COUnsafeRetainedMutableArray : COMutableArray
@end

@interface COMutableDictionary : NSMutableDictionary <COPrimitiveCollection>
{
	@public
	BOOL _mutable;
	NSMutableDictionary *_backing;
	NSMutableSet *_deadKeys;
}
- (void)setDeadPath: (COPath *)aPath forKey: (id <NSCopying>)aKey;
@end
