/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COObject;

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
}
@end

@interface COMutableArray : NSMutableArray <COPrimitiveCollection>
{
@public
	BOOL _mutable;
	NSPointerArray *_backing;
}
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
}
@end
