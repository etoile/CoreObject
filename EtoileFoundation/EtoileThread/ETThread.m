/*
	ETThread.m

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

#import "ETThread.h"

struct ETThreadInitialiser
{
	id object;
	SEL selector;
	id target;
	ETThread *thread;
};

static pthread_key_t threadObjectKey;

/* Thread creation trampoline */
void * threadStart(void* initialiser)
{
#ifdef GNUSTEP
	GSRegisterCurrentThread ();
#endif
	struct ETThreadInitialiser *init = initialiser;
	id object = init->object;
	id target = init->target;
	SEL selector = init->selector;
	ETThread *thread = init->thread;

	free(init);
	pthread_setspecific(threadObjectKey, thread);
	thread->pool = [[NSAutoreleasePool alloc] init];

	id result = [target performSelector:selector 
				  		     withObject:object];

	// NOTE: Not reached if exitWithValue: is called
	[thread->pool release];
	[thread release];

	return result;
}

@implementation ETThread

+ (void) initialize
{
	NSLog(@"Going multithreaded.");
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NSWillBecomeMultiThreadedNotification
		              object:nil];
	pthread_key_create(&threadObjectKey, NULL);
}

+ (id) detachNewThreadSelector: (SEL)aSelector 
                      toTarget: (id)aTarget 
                    withObject: (id)anArgument
{
	ETThread *thread = [[ETThread alloc] init];

	if (thread == nil)
	{
		return nil;
	}

	struct ETThreadInitialiser *threadArgs = 
		malloc(sizeof(struct ETThreadInitialiser));
	threadArgs->object = anArgument;
	threadArgs->selector = aSelector;
	threadArgs->thread = thread;
	threadArgs->target = aTarget;
	pthread_create(&thread->thread, NULL, threadStart, threadArgs);

	return thread;
}

+ (ETThread *) currentThread
{
	return (ETThread *)pthread_getspecific(threadObjectKey);
}

- (id) waitForTermination
{
	void *retVal = nil;
	pthread_join(thread, &retVal);
	return (id)retVal;
}

- (BOOL) isCurrentThread
{
	if (pthread_equal(pthread_self(), thread) == 0)
	{
		return YES;
	}
	return NO;
}

- (void) exitWithValue: (id)aValue
{
	if ([self isCurrentThread])
	{
		[pool release];
		[self release];
		pthread_exit(aValue);
	}
}

/* This shouldn't normally be used, since it will normally leak memory */
- (void) kill
{
	pthread_cancel(thread);
}

- (void) dealloc
{
	/* If no one has a reference to this object, don't keep the return value
	 * around */
	// NOTE: It might be worth catching the return value and releasing it to
	// prevent leaking.
	pthread_detach(thread);
	[super dealloc];
}

@end
