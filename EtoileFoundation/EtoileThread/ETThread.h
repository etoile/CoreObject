/*
	ETThread.h

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
#include <pthread.h>

/**
 * The ETThread class provides a wrapper around basic POSIX threading 
 * functionality.  This extends NSThread by allowing a thread to wait
 * for another to terminate, and for an exit value to be returned.
 */
@interface ETThread : NSObject 
{
	pthread_t thread;
@public
	NSAutoreleasePool *pool;
}
/**
 * Similar to NSThread's method of the same name.  Creates a new thread and
 * invokes [aTarget aSelector:anArgument].  Unlike the NSThread implementation,
 * this creates an NSAutoreleasePool before performing the selector and then
 * frees it afterwards.  This method can thus be used on any side-effect-free
 * method, without modification.
 */
+ (id) detachNewThreadSelector: (SEL)aSelector 
                      toTarget: (id)aTarget 
                    withObject: (id)anArgument;
/**
 * Returns an ETThread representing the current thread.  The behaviour for this
 * method is undefined if called from a thread not created by an ETThread.
 */
+ (ETThread *) currentThread;
/**
 * Blocks execution in the caller until the thread exits.  If the method used 
 * to create the thread returns a value, or the thread is terminated with
 * -exitWithValue: then this method will give the returned value.
 */
- (id) waitForTermination;
/**
 * Returns YES if the receiver represents the callers thread, NO otherwise.
 */
- (BOOL) isCurrentThread;
/**
 * Causes immediate termination of the thread and returns the specified value.
 * This method can only be called from the thread represented by the receiver
 * and will silently fail otherwise.  
 */
- (void) exitWithValue: (id)aValue;
/**
 * Causes immediate termination of the receiver's thread.
 */
- (void) kill;
@end
