/*
 *  Macros.h
 *
 *  Created by David Chisnall on 02/08/2005.
 *
 */

/**
 * Simple macro for safely initialising the superclass.
 */
#define SUPERINIT if((self = [super init]) == nil) {return nil;}
/**
 * Deprecated. You should use the designated initializer rule.
 * 
 * Simple macro for safely initialising the current class.
 */
#define SELFINIT if((self = [self init]) == nil) {return nil;}
/**
 * Macro for creating dealloc methods.
 */
#define DEALLOC(x) - (void) dealloc { x ; [super dealloc]; }

@protocol MakeReleaseSelectorNotFoundErrorGoAway
- (void) release;
@end

/**
 * Cleanup function used for stack-scoped objects.
 */
__attribute__((unused)) static inline void ETStackAutoRelease(void* object)
{
	[*(id*)object release];
}
/**
 * Macro used to declare objects with lexical scoping.  The object will be sent
 * a release message when it goes out of scope.  
 *
 * Example:
 *
 * STACK_SCOPED Foo * foo = [[Foo alloc] init];
 */
#define STACK_SCOPED __attribute__((cleanup(ETStackAutoRelease))) \
		__attribute__((unused))

@interface NSLocking
- (void)lock;
- (void)unlock;
@end

/**
 * Cleanup function that releases a lock.
 */
__attribute__((unused)) static inline void ETUnlockObject(void* object)
{
	[*(id*)object unlock];
}
/**
 * Macro that sends a -lock message to the argument immediately, and then an
 * -unlock message when the variable goes out of scope (including if an
 *  exception causes this stack frame to be unwound).
 */
#define LOCK_FOR_SCOPE(x) __attribute__((cleanup(ETUnlockObject))) \
		__attribute__((unused)) id __COUNTER__ ## _lock = x; [x lock]

/**
 * Create a temporary autorelease pool that is destroyed when the scope exits.
 */
#define LOCAL_AUTORELEASE_POOL() STACK_SCOPED \
	NSAutoreleasePool *__COUNTER__ ## _pool = [NSAutoreleasePool new];

/**
 * Set of macros providing a for each statement on collections, with IMP
 * caching.
 */
#define FOREACHI(collection,object) FOREACH(collection,object,id)

#ifdef __clang__
#	define FOREACH(collection,object,type) for (type object in [collection objectEnumerator])
#else
#	define FOREACH(collection,object,type) FOREACH_WITH_ENUMERATOR_NAME(collection,object,type,object ## enumerator)
#endif

#define FOREACH_WITH_ENUMERATOR_NAME(collection,object,type,enumerator)\
NSEnumerator * enumerator = [collection objectEnumerator];\
FOREACHE(collection,object,type,enumerator)

#ifdef __clang__
#	define FOREACHE(collection,object,type,enumerator)\
	for (type object in enumerator)
#else
#	define FOREACHE(collection,object,type,enumerator)\
type object;\
IMP next ## object ## in ## enumerator = \
[enumerator methodForSelector:@selector(nextObject)];\
while(enumerator != nil && (object = next ## object ## in ## enumerator(\
												   enumerator,\
												   @selector(nextObject))))
#endif

#define D(...) [NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__ , nil]
#define A(...) [NSArray arrayWithObjects:__VA_ARGS__ , nil]
#define S(...) [NSSet setWithObjects:__VA_ARGS__ , nil]

#ifdef DEFINE_STRINGS
#define EMIT_STRING(x) NSString *x = @"" # x;
#endif
#ifndef EMIT_STRING
#define EMIT_STRING(x) extern NSString *x;
#endif

/** Basic assertion macro that just reports the tested condition when it fails.
It is similar to NSParameterAssert but not limited to checking the arguments. */
#define ETAssert(condition)	\
	NSAssert1(condition, @"Failed to satisfy %s", #condition)
/** Same as ETAssert except it gets executed only if you define  
ETDebugAssertionEnabled.

This macro can be used to do more expansive checks that cannot be kept turned 
on in a release version. */
#ifdef ETDebugAssertionEnabled
#define ETDebugAssert(condition) \
	ETAssert(condition)
#else
#define ETDebugAssert(condition)
#endif
/** Assertion macro to mark code portion that should never be reached. e.g. the 
default case in a switch statement. */
#define ETAssertUnreachable() \
	NSAssert(NO, @"Entered code portion which should never be reached")

/** Exception macro to check whether the given argument respects a condition.<br />
When the condition evaluates to NO, an NSInvalidArgumentException is raised. */
#define INVALIDARG_EXCEPTION_TEST(arg, condition) do { \
	if (NO == (condition)) \
	{ \
		[NSException raise: NSInvalidArgumentException format: @"For %@, %s " \
			"must respect %s", NSStringFromSelector(_cmd), #arg , #condition]; \
	} \
} while (0);
/** Exception macro to check the given argument is not nil, otherwise an 
NSInvalidArgumentException is raised. */
#define NILARG_EXCEPTION_TEST(arg) do { \
	if (nil == arg) \
	{ \
		[NSException raise: NSInvalidArgumentException format: @"For %@, " \
			"%s must not be nil", NSStringFromSelector(_cmd), #arg]; \
	} \
} while(0);
