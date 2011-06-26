/*
	NSObject+Threaded.h

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

/**
 * Threaded objects should implement the Idle protocol if they wish to do
 * something while waiting for messages.  If they have work to do, they should
 * return YES to -shouldIdle, which will cause -idle to be called.  If they
 * return NO then the object will enter a blocking state until it receives a
 * message from the creating thread, after which it will attempt to run the
 * idle method again.
 */
@protocol Idle
/**
 * Returns YES if the object's idle method should be called.
 */
- (BOOL) shouldIdle;
/**
 * Method which will be called in an object when there are no messages waiting
 * for it.
 */
- (void) idle;
@end

/**
 * The Threaded category adds methods to NSObject
 * for creating object graphs in another thread.
 */
@interface NSObject (Threaded)
/**
 * Create an instance of the object in a new thread
 * with an associated run loop.
 */
+ (id) threadedNew;
/**
 * Returns a trampoline object that can be used to 
 * execute a method on the called object in a new thread.
 */
- (id) inNewThread;
@end
