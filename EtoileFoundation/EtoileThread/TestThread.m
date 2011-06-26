/*
	TestThread.m

	Copyright (C) 2008 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  November 2008

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
#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/EtoileFoundation.h>

static BOOL deallocCalled;

@interface ThreadTestClass : NSObject
{
	NSObject *test;
}

- (id) init;
- (NSObject *) test;

@end

@implementation ThreadTestClass

- (id) init
{
	SUPERINIT;
	test = [[NSObject alloc] init];
	return self;
}

- (void) dealloc
{
	deallocCalled = YES;
	[test release];
	[super dealloc];
}

- (NSObject *) test
{
	return test;
}

@end



@interface TestThread : NSObject <UKTest>
@end

@implementation TestThread

- (void) testObjectReturn
{
	id pool = [[NSAutoreleasePool alloc] init];
	id object = [ThreadTestClass threadedNew];
	
	id ret;
	for (unsigned i =0; i<10000; i++)
	{
		id pool = [NSAutoreleasePool new];
		ret = [object test];
		usleep(i % 500);
		[ret value];
		[pool release];
	}
	
	[object release];
	[pool release];
	UKPass();
}

- (void) testObjectReturnRetainCount
{
	deallocCalled = NO;

	id pool = [[NSAutoreleasePool alloc] init];
	id object = [NSMutableArray threadedNew];
	[object addObject: [[[ThreadTestClass alloc] init] autorelease]];

	[[object objectAtIndex: 0] description];

	[object release];
 	[pool release];

	sleep(1);
	UKTrue(deallocCalled);
}

- (void) testThreadedNewRetainCount
{
	deallocCalled = NO;
	
	id pool = [[NSAutoreleasePool alloc] init];
	id object = [ThreadTestClass threadedNew];
	[object release];
	[pool release];

	sleep(1);
	UKTrue(deallocCalled);
}

- (void) testInNewThreadRetainCount
{
	deallocCalled = NO;
	
	id pool = [[NSAutoreleasePool alloc] init];
	id object = [[[[ThreadTestClass alloc] init] autorelease] inNewThread];
	[pool release];

	sleep(1);
	UKTrue(deallocCalled);
}

@end
