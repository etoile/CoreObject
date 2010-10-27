/*
	ETFilter.h
	
	Generic object chain class to implement late-binding of behavior
	through delegation.
 
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
#import <EtoileFoundation/ETObjectChain.h>
#import <EtoileFoundation/ETRendering.h>

// NOTE: May be define an ETFilterChain formal protocol

/** Filter class is widely used in both EtoileFoundation and higher level 
	frameworks like EtoileUI to implement pervasive late-binding of behavior
	or state. Object chains are implemented as a linked lists.
	Many classes in EtoileFoundation and EtoileUI are subclasses of ETFilter
	and thereby benefit from the built-in support of delegation chain.
	In addition to delegation and changing behavior of objects at runtime,
	the class also provides a common interface for applying transforms.
	See ETTransform and related subclasses.
	Take note ETStyle provides a mostly identical class in EtoileUI. ETStyle is
	state oriented, it is used to represent objects that have a visual 
	representation or translation (like style, layout, brush stroke etc.) and
	display them on screen. 
	ETFilter is behavior-oriented, it is used to handle filtering, 
	transforming and converting where you give data in input and you get 
	other data in output. 
	
	input | type  |  output
	data -> style -> display
	data -> filter -> data  
	
	ETStyle is a typical renderer object. */

@interface ETFilter : ETObjectChain <ETRendering>
{
	id _nextFilter;
}

/* Initialization */

- (id) initWithFilter: (ETFilter *)filter;
- (id) initWithCollection: (id <ETCollection>)filters;

/* Filter Chaining */

- (ETFilter *) nextFilter;
- (void) setNextFilter: (ETFilter *)filter;
- (ETFilter *) lastFilter;

/* Filter Processing */

- (SEL) filterSelector;
- (id) render: (id)object;

// TODO: Provides filter collection access in subclasses that introduces 
// another main structural collection
// [[layoutItemGroup asFilterCollection] objectEnumerator]
// -asFilter or -asFilterCollection

@end
