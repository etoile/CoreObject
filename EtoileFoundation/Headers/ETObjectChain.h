/*
	ETObjectChain.h
	
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

#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETCollection.h>


/** Object chain class is widely used in both EtoileFoundation and higher level 
	frameworks like EtoileUI to implement pervasive late-binding of behavior
	or state. Object chains are implemented as a linked lists. */

@interface ETObjectChain : NSObject <ETCollection, ETCollectionMutation>
{
	id _nextObject;
}

/* Initialization */

- (id) initWithObject: (ETObjectChain *)object;
- (id) initWithCollection: (id <ETCollection>)objects;

/* Object Chaining */

- (ETObjectChain *) nextObject;
- (void) setNextObject: (ETObjectChain *)object;
- (ETObjectChain *) lastObject;

/* Collection Protocol */

- (BOOL) isOrdered;
- (BOOL) isEmpty;
- (id) content;
- (NSArray *) contentArray;
- (void) addObject: (id)object;
- (void) insertObject: (id)object atIndex: (unsigned int)index;
- (void) removeObject: (id)object;

// TODO: Provides object chain collection access in subclasses that introduces 
// another main structural collection
// [[layoutItemGroup asObjectChainCollection] objectEnumerator]
// -asObjectChain or -asObjectChainCollection

@end
