/*
	ETThreadedObject.h

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

#import <Foundation/Foundation.h>
#import <EtoileThread/ETThread.h>
#import <EtoileThread/NSObject+Threaded.h>
#include <pthread.h>

#define QUEUE_SIZE 256
#define QUEUE_MASK 0xff

/**
 * The ETThreadedObject class represents an object which has its
 * own thread and run loop.  Messages that return either an object
 * or void will, when sent to this object, return asynchronously.
 *
 * For methods returning an object, an [ETThreadProxyReturn] will
 * be returned immediately.  Messages passed to this object will
 * block until the real return value is ready.
 *
 * In general, methods in this class should not be called directly.
 * Instead, the [NSObject(Threaded)+threadedNew] method should be 
 * used.
 */
@interface ETThreadedObject : NSProxy
{
	/**
	 * Proxied object.
	 */
	id object;
	/** 
	 * The condition variable and mutex are only used when the queue is empty.
	 * If the message queue is kept fed then the class moves to a lockless
	 * model for communication.
	 */
	pthread_cond_t conditionVariable;
	pthread_mutex_t mutex;
	/**
	 * Lockless ring buffer and free-running counters.
	 */
	id invocations[QUEUE_SIZE];
	unsigned long producer;
	unsigned long consumer;
	id proxy;
	BOOL terminate;
	ETThread *thread;
}
/**
 * Create a threaded instance of aClass
 */
- (id) initWithClass: (Class)aClass;
/**
 * Create a thread and run loop for anObject
 */
- (id) initWithObject: (id)anObject;
/**
 * Method encapsulating the run loop.  Should not be called directly
 */
- (void) runloop: (id)sender;
@end
