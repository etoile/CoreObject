/*
	ETThreadedObject.m

	Copyright (C) 2007 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  January 2007

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ETThreadedObject.h"
#import "ETThreadProxyReturn.h"
#include <sched.h>

/**
 * GCC 4.1 provides atomic operations which impose memory barriers.  These are
 * not needed on x86, but might be on other platforms (anything that does not
 * enforce strong ordering of memory operations, e.g. Itanium or Alpha).
 */
#if __GNUC__ < 4 || (__GNUC__ == 4 && __GNUC_MINOR__ < 1)
#warning Potentially unsafe memory operations being used
static inline void __sync_fetch_and_add(unsigned long *ptr, unsigned int value)
{
	*ptr += value;
}
#endif

/**
 * Ring buffer implementation:
 * 
 * The ring buffer has three components:
 *
 * invocations - an array of QUEUE_SIZE elements (ids) which contains the
 * buffer itself.
 * 
 * producer - a free running counter indicating the index at which objects
 * should be inserted into the buffer.  Only incremented by the inserting
 * thread.
 *
 * consumer - a free running counter indicating the index at which objects
 * should be removed from the buffer.  Only incremented by the removing thread.
 *
 * These, together, provide a lockless ring buffer (FIFO) implementation. 
 */

/**
 * Check how much space is in the queue.  The number of used elements in the
 * queue is always equal to producer - consumer.   Producer will always
 * overflow before consumer (because you can't remove objects that have not
 * been inserted.  In this case, the subtraction will be something along the
 * lines of (0 - (2^32 - 14)).  This will be -(2^32 - 14), however this value
 * can't be represented in a 32-bit integer and so will overflow to 14, giving
 * the correct result, irrespective of overflow.  
 */
#define SPACE (QUEUE_SIZE - (producer - consumer))
/**
 * The buffer is full if there is no space in it.
 */
#define ISFULL (SPACE == 0)
/**
 * The buffer is empty if there is no data in it.
 */
#define ISEMPTY ((producer - consumer) == 0)
/**
 * Converting the free running counters to array indexes is a masking
 * operation.  For this to work, the buffer size must be a power of two.
 * QUEUE_MASK = QUEUE_SIZE - 1.  If QUEUE_SIZE is 256, we want the lowest 8
 * bits of the index, which is obtained by ANDing the value with 255.  Any
 * power of two may be selected.  Non power-of-two values could be used if a
 * more complex mapping operation were chosen, but this one is nice and cheap.
 */
#define MASK(index) ((index) & QUEUE_MASK)
/**
 * Inserting an element into the queue involves the following steps:
 *
 * 1) Check that there is space in the buffer.
 *     Spin if there isn't any.
 * 2) Add the invocation and optionally the proxy containing the return value
 * (nil for none) to the next two elements in the ring buffer.
 * 3) Increment the producer counter (by two, since we are adding two elements).
 * 4) If the queue was previously empty, we need to transition back to lockless
 * mode.  This is done by signalling the condition variable that the other
 * thread will be waiting on if it is in blocking mode.
 */
#define INSERT(x,r) do {\
	/* Wait for space in the buffer */\
	while (ISFULL)\
	{\
		sched_yield();\
	}\
	invocations[MASK(producer)] = x;\
	invocations[MASK(producer+1)] = r;\
	__sync_fetch_and_add(&producer, 2);\
	if (producer - consumer == 2)\
	{\
		pthread_mutex_lock(&mutex);\
		pthread_cond_signal(&conditionVariable);\
		pthread_mutex_unlock(&mutex);\
	}\
} while(0);
/**
 * Removing an element from the queue involves the following steps:
 *
 * 1) Wait until the queue has messages waiting.  If there are none, enter
 * blocking mode.  The additional test inside the mutex ensures that a
 * transition from blocking to non-blocking mode will not be missed, since the
 * condition variable can only be signalled when the producer thread has the
 * mutex.  
 * 2) Read the invocation and return proxy from the buffer.
 * 3) Incrememt the consumer counter.
 */
#define REMOVE(x,r) do {\
	while (ISEMPTY)\
	{\
		if (terminate) { return; }\
		if (idle && [object shouldIdle])\
		{\
			[object idle];\
		}\
		else\
		{\
			pthread_mutex_lock(&mutex);\
			if (ISEMPTY)\
			{\
					pthread_cond_wait(&conditionVariable, &mutex);\
			}\
			pthread_mutex_unlock(&mutex);\
		}\
	}\
	x = invocations[MASK(consumer)];\
	r = invocations[MASK(consumer+1)];\
	__sync_fetch_and_add(&consumer, 2);\
} while(0);


@interface NSInvocation (_Private)
/**
 * Exposes the private method which tells the NSInvocation not to store its
 * return value in the original location.
 */
- (void) _storeRetval;
@end


@implementation ETThreadedObject
// Remove this when GNUstep is fixed.
+ (void) initialize
{
	if (Nil != NSClassFromString(@"GSFFCallInvocation"))
	{
		NSLog(@"WARNING: You are using FFCall-based NSInvocations.  "
				"This will result in random stack corruption.  "
				"Any bugs you file will be ignored.");
	}
}

/* Designated initializer */
- (id) init
{
	pthread_cond_init(&conditionVariable, NULL);
	pthread_mutex_init(&mutex, NULL);
	return self;
}

- (id) initWithClass: (Class)aClass
{
	if (nil == (self = [self init]))
	{
		return nil;
	}
	object = [[aClass alloc] init];
	return self;
}

- (id) initWithObject: (id)anObject
{
	if (nil == (self = [self init]))
	{
		return nil;
	}
	// Retained in the creating thread.
	object = anObject;
	return self;
}

- (void) dealloc
{
	/* Instruct worker thread to exit */
	pthread_mutex_lock(&mutex);
	terminate = YES;

	/* Wait for worker thread to let us know which thread object belongs to it*/
	while (thread == nil)
	{
		pthread_cond_signal(&conditionVariable);
		pthread_mutex_unlock(&mutex);
		pthread_mutex_lock(&mutex);
	}
	pthread_cond_signal(&conditionVariable);
	pthread_mutex_unlock(&mutex);

	/* Wait for worker thread to terminate */
	[thread waitForTermination];
	[thread release];

	/* Destroy synchronisation objects */
	pthread_cond_destroy(&conditionVariable);
	pthread_mutex_destroy(&mutex);

	[object release];

	[super dealloc];
}

- (void) runloop: (id)sender
{
	thread = [[ETThread currentThread] retain];
	BOOL idle = [object conformsToProtocol: @protocol(Idle)];
	while (object)
	{
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		/* Take the first invocation from the queue */
		NSInvocation * anInvocation;

		ETThreadProxyReturn *retVal;
		REMOVE(anInvocation, retVal);

		// If we are returning an object, we don't want to be overwriting the
		// proxy on the stack.
		if (retVal != nil)
		{
			[anInvocation _storeRetval];
		}
		[anInvocation invokeWithTarget:object];
		if (retVal != nil)
		{
			id realReturn;
			[anInvocation getReturnValue:&realReturn];
			[retVal setProxyObject:realReturn];
			/*
			  Proxy return object is created with a retain count of 2 and an
			  autorelease count of 1 in the main thread.  This will set it to a
			  retain count of 1 and an autorelease count of 1 if it has not
			  been used, or dealloc it if it has
			*/
			//[retVal release];
		}

		[anInvocation setTarget: nil];
		[anInvocation release];
		[pool release];
	}
	NSLog(@"Thread exiting");
	[NSThread exit];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
	return [object methodSignatureForSelector:aSelector];
}

- (id) returnProxy
{
	return proxy;
}

- (void) forwardInvocation: (NSInvocation *)anInvocation
{
	BOOL concreteType = NO;
	int rc = [anInvocation retainCount];

	if (![anInvocation argumentsRetained])
	{
		[anInvocation retainArguments];
	}

	ETThreadProxyReturn * retVal = nil;
	char returnType = [[anInvocation methodSignature] methodReturnType][0];

	if (returnType == '@')
	{
		retVal = [[[ETThreadProxyReturn alloc] init] autorelease];
		proxy = retVal;
		/*
		  This is a hack to force the invocation to stop blocking the caller.
		*/
		SEL selector = [anInvocation selector];
		[anInvocation setSelector:@selector(returnProxy)];
		[anInvocation invokeWithTarget:self];
		[anInvocation setSelector:selector];
	}
	//Non-void, non-object, return
	else if (returnType != 'v')
	{
		/*
		 * This is a hack.. if the method returns a concrete type (eg not an
		 * object) the result is immediately assigned as soon a
		 * forwardInvocation: ends.  As the invocation is not yet invoked, that
		 * means we get default values instead of the correct returned value
		 * (eg, with a method returning an int, say 42, the actual value
		 * returned will be 0) But as we can't call the invocation ourself
		 * (that would break the invocations order) we need to wait until the
		 * runloop invoke it. We could use a condition variable to signal that
		 * the invocation is ready, but a faster way is to poll until the
		 * invocation is done (no context switch that way).  There doesn't seem
		 * to be a method returning the invocation status, therefore we simply
		 * increment the retain count before adding the invocation to the
		 * runloop.  In the runloop we decrement the retain count once the
		 * invocation is invoked, and we just wait until the retain count
		 * equals the original count.
		 */
		concreteType = YES;
	}
	[anInvocation retain];
	INSERT(anInvocation, retVal);

	if (concreteType)
	{
		while ([anInvocation retainCount] > rc) 
		{
			// do nothing... just poll...
			sched_yield();
		}
	}
}

@end
