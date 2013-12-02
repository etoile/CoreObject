/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  December 2013
	License:  Modified BSD  (see COPYING)
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


@interface COUnsafeRetainedMutableSet : NSMutableSet
{
	@public
	BOOL _mutable;
	NSHashTable *_backing;
}
@end

@interface COUnsafeRetainedMutableArray : NSMutableArray
{
	@public
	BOOL _mutable;
	NSPointerArray *_backing;
}
@end

@interface COMutableDictionary : NSMutableDictionary
{
	@public
	BOOL _mutable;
	NSMutableDictionary *_backing;
}
@end


@interface NSObject (COPrimitiveCollection)
+ (Class)coreObjectClass;
- (id)mutableCoreObjectCopy;
@end

@interface NSArray (COPrimitiveCollection)
+ (Class)coreObjectClass;
- (id)mutableCoreObjectCopy;
@end

@interface NSSet (COPrimitiveCollection)
+ (Class)coreObjectClass;
- (id)mutableCoreObjectCopy;
@end

@interface NSDictionary (COPrimitiveCollection)
+ (Class)coreObjectClass;
- (id)mutableCoreObjectCopy;
@end


