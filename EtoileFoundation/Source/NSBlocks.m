#import <Foundation/NSObject.h>
#import "objc/blocks_runtime.h"

@interface NSBlock
{
	id isa;
}
@end

@implementation NSBlock
+ (void)load
{
	unsigned int methodCount;
	Method *methods = 
		class_copyMethodList(objc_getClass("NSBlock"), &methodCount);
	id blockClass = objc_lookUpClass("_NSBlock");
	for (Method *m = methods ; NULL!=*m ; m++)
	{
		class_addMethod(blockClass, method_getName(*m),
			method_getImplementation(*m), method_getTypeEncoding(*m));
	}
}
- (id)copyWithZone: (NSZone*)aZone
{
	return Block_copy(self);
}
- (id)copy
{
	return Block_copy(self);
}
- (id)retain
{
	return Block_copy(self);
}
- (void)release
{
	Block_release(self);
}

// Define __has_feature() for compilers that don't support it.
#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if __has_feature(blocks)
- (id) value
{
	return ((id(^)(void))self)();
}
- (id) value: (id)anObject
{
	return ((id(^)(id))self)(anObject);
}
- (id) value: (id)anObject value: (id)obj2
{
	return ((id(^)(id,id))self)(anObject, obj2);
}
- (id) value: (id)anObject value: (id)obj2 value: (id)obj3
{
	return ((id(^)(id,id,id))self)(anObject, obj2, obj3);
}
#endif
@end

