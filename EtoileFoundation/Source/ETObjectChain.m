/*
	ETObjectChain.m
	
	Generic object chain class based on a linked list
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  November 2007
 
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
 
#import <EtoileFoundation/ETObjectChain.h>
#import <EtoileFoundation/EtoileCompatibility.h>

@interface ETObjectChain (Private)
- (void) _buildLinkedListWithCollection: (id <ETCollection>)objects;
@end


@implementation ETObjectChain

+ (NSString *) prefixName
{
	return @"ET";
}

/** Returns a new object chain connected to an existing object chain. */
- (id) initWithObject: (ETObjectChain *)object
{
	return [self initWithCollection: [NSArray arrayWithObject: object]];
}

/** <init /> Returns a new object chain by chaining objects passed as parameter */
- (id) initWithCollection: (id <ETCollection>)objects
{
	self = [super init];
	
	if (self != nil)
	{
		[self _buildLinkedListWithCollection: objects];
	}
	
	return self;
}

- (void) _buildLinkedListWithCollection: (id <ETCollection>)objects
{
	// TODO: Remove -contentArray call once we have found a way to declare 
	// already implemented methods in a protocol and adopts this protocol by the 
	// mean of a category (take a look at ETCollection).
	NSEnumerator *e = [[objects contentArray] objectEnumerator];
	id prevObject = self;
	id object = nil;
	
	while ((object = [e nextObject]) != nil)
	{
		[prevObject setNextObject: object];
		prevObject = object;
	}
}

- (void) dealloc
{
	DESTROY(_nextObject);
	
	[super dealloc];
}

/** Returns the object following the receiver in the object chain. */
- (ETObjectChain *) nextObject
{
	return _nextObject;
}

/** Sets the object following the receiver in the object chain. 
	Take note this method discards the existing next object and the whole 
	object chain connected to it. If you want to reconnect the existing 
	next object, it's up to you to handle it. */
- (void) setNextObject: (ETObjectChain *)object
{
	ASSIGN(_nextObject, object);
}

/** Returns the object terminating the object chain the receiver belongs
	to. In other words, returns the first object that has no next object 
	connected to it. */
- (ETObjectChain *) lastObject
{
	id nextObject = [self nextObject];

	if (nextObject != nil)
	{
		return [nextObject lastObject];
	}
	else
	{	
		return self;
	}
}

/* Collection Protocol */

- (BOOL) isOrdered
{
	return YES;
}

- (BOOL) isEmpty
{
	return ([self nextObject] == nil);
}

- (id) content
{
	return self;
}

- (NSArray *) contentArray
{
	NSMutableArray *objectArray = [NSMutableArray array];
	id object = self;
	
	while (object != nil)
	{
		[objectArray addObject: object];
		object = [object nextObject];
	}
	
	return objectArray;
}

- (void) addObject: (id)object
{
	[[self lastObject] setNextObject: object];
}

- (void) insertObject: (id)object atIndex: (unsigned int)index
{
	if (index == 0)
	{
		[object setNextObject: self];
	}
	else
	{
		id prevObject = self;
		int i = 1;
		
		do {
			if (i == index)
			{
				[prevObject setNextObject: object];
				break;
			}
			else
			{
				i++;
			}
		} while ((prevObject = [prevObject nextObject]) != nil);
	}
}

/** You cannot remove the head of an object chain with this method. If you want
    to, you must retrieve the object following the head to keep a reference to
	the object chain and do -[head setNextObject: nil]. */
- (void) removeObject: (id)object
{
	id prevObject = self;
	id nextObject = [prevObject nextObject];
	
	if ([nextObject isEqual: object])
	{
		[prevObject setNextObject: [nextObject nextObject]];
		/* We continue to remove all occurences in a case we have multiple 
		   instances that reply YES to -isEqual: */
		[[prevObject nextObject] removeObject: object];
	}
	else
	{
		[nextObject removeObject: object];	
	}

}

@end
