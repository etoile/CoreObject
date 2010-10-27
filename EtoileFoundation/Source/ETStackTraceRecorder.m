/*
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2010
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/NSDebug.h>
#import "ETStackTraceRecorder.h"
#import "ETCollection.h"
#import "EtoileCompatibility.h"
#import "Macros.h"
#import <objc/Object.h>

@interface ETStackTraceRecorder (Private)
- (void) didAllocObject: (id)anObject ofClass: (Class)aClass;
- (void) didDeallocObject: (id)anObject ofClass: (Class)aClass;
@end

ETStackTraceRecorder *sharedInstance = nil;

static void ETAllocateCallback(Class aClass, id self)
{
	[sharedInstance didAllocObject: self ofClass: aClass];
}

static void ETDeallocateCallback(Class aClass, id self)
{
	[sharedInstance didDeallocObject: self ofClass: aClass];
}


@implementation ETStackTraceRecorder

/** Returns the shared stack trace recorder. */
+ (id) sharedInstance
{
	if (nil == sharedInstance)
	{
		// FIXME: @synchronized(self)
		{
			sharedInstance = [[self alloc] init];
		}
	}
	return sharedInstance;
}

/** <init />
Initializes and returns a new stack trace recorder. */
- (id) init
{
	SUPERINIT;

	/* To prevent any message to be sent to an object (which might be partially 
	   deallocated or might not implement it e.g. -hash), we treat each object 
	   as a raw pointer in its key role for the map table.
	   NOTE: For keyFuncs, NSPointerFunctionsZeroingWeakMemory could be better */
	NSPointerFunctions *keyFuncs = [NSPointerFunctions pointerFunctionsWithOptions: 
		NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality];
	NSPointerFunctions *valueFuncs = [NSPointerFunctions pointerFunctionsWithOptions: 
		NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];

	_tracesByObject = [[NSMapTable alloc] initWithKeyPointerFunctions: keyFuncs 
	                                            valuePointerFunctions: valueFuncs
	                                                         capacity: 50000];
	_lock = [[NSLock alloc] init];
	_allocMonitoredClasses = [[NSMutableSet alloc] init];
	return self;
}

- (void) dealloc
{
	DESTROY(_tracesByObject);
	DESTROY(_lock);
	DESTROY(_allocMonitoredClasses);
	[super dealloc];
}

- (void) didAllocObject: (id)anObject ofClass: (Class)aClass
{
	if ([_allocMonitoredClasses containsObject: aClass] == NO)
		return;

	[self recordForObject: anObject];
}

- (void) didDeallocObject: (id)anObject ofClass: (Class)aClass
{
	// NOTE: We could eventually discard the given object stack traces when 
	// NSZombieEnabled is NO.
	//[_tracesByObject removeObjectForKey: anObject];
}

#ifdef GNUSTEP

/** Enables the recording of the stack trace every time +allocWithZone: 
is called on the given class.

Doesn't apply to subclasses. e.g. Using NSObject as argument won't trigger the 
allocation recording for every instances.<br />
You must pass concrete subclasses to record class cluster allocations. e.g. 
GSDictionary for NSDictionary.

For now, using this method on other recorders than the one returned by 
+sharedInstance is not supported.

To detect object allocations, the receiver sets up alloc/dealloc callbacks with 
GSSetDebugAllocationFunctions(). You cannot use these hooks in your code and at 
the same time record the allocation with ETStackTraceRecorder.  */
- (void) enableAllocationRecordingForClass: (Class)aClass;
{
	ETAssert([self isEqual: sharedInstance]);

	[_allocMonitoredClasses addObject: aClass];
	GSSetDebugAllocationFunctions(&ETAllocateCallback, &ETDeallocateCallback);
}

/** Disables the recording of the stack trace every time +allocWithZone: 
is called on the given class.

Doesn't apply subclasses. See -enableAllocationRecordingForClass: for more details. */
- (void) disableAllocationRecordingForClass: (Class)aClass
{
	ETAssert([self isEqual: sharedInstance]);

	[_allocMonitoredClasses removeObject: aClass];
	if ([_allocMonitoredClasses isEmpty])
	{
		GSSetDebugAllocationFunctions(NULL, NULL);
	}
}

#endif

/** Records the call stack symbols in relation to the given object. */
- (void) recordForObject: (id)anObject
{
	NSThread *currentThread = [NSThread currentThread];
	BOOL isRecordingInCurrentThread = (_recordThread == currentThread);

	if (isRecordingInCurrentThread)
		return;

	[_lock lock];
	_recordThread = currentThread;

	NSMutableArray *traces = [_tracesByObject objectForKey: anObject];

	if (nil == traces)
	{
		traces = [NSMutableArray array];
		[_tracesByObject setObject: traces forKey: anObject];
	}
	[traces addObject: AUTORELEASE([[ETStackTrace alloc] init])];

	_recordThread = nil;
	[_lock unlock];
}

/** Returns an array of stack traces previous recorded with -recordForObject: 
for the given object.

When no stack traces have been recorded for the given object, returns an empty
array. */ 
- (NSArray *) recordedStackTracesForObject: (id)anObject
{
	NSArray *trace = [_tracesByObject objectForKey: anObject];
	
	return (nil == trace ? [NSArray array] : AUTORELEASE([trace copy]));
}

@end


@implementation NSObject (ETStackTraceRecorderConveniency)

/** Records the call stack symbols with the shared stack trace recorder. */
- (void) recordStackTrace
{
	[[ETStackTraceRecorder sharedInstance] recordForObject: self];
}

/** Returns an array of stack traces previously recorded with the shared stack 
trace recorded for the receiver. */
- (NSArray *) recordedStackTraces
{
	return [[ETStackTraceRecorder sharedInstance] recordedStackTracesForObject: self];
}

@end


@implementation ETStackTrace

+ (NSArray *) callStackSymbols
{
#ifdef GNUSTEP
	id stackTraceObj = AUTORELEASE([[NSClassFromString(@"GSStackTrace") alloc] init]);
	return [stackTraceObj performSelector: @selector(symbols)];
#else
	return [[NSThread currentThread] callStackSymbols];
#endif
}

/** <init />
Returns a new stack trace initialized with the call stack symbols of the 
current thread. */
- (id) init
{
	SUPERINIT;
	ASSIGN(_callStackSymbols, [[self class] callStackSymbols]);
	return self;
}

- (void) dealloc
{
	DESTROY(_callStackSymbols);
	[super dealloc];
}

/** Returns the number of stack frames. */
- (NSUInteger) numberOfFrames
{
	return [_callStackSymbols count];
}

- (NSString *) description
{
	NSString *desc = @"";

	FOREACH(_callStackSymbols, symbol, NSString *)
	{
		desc = [desc stringByAppendingFormat: @"%@\n", symbol];
	}
	return desc;
}

@end
