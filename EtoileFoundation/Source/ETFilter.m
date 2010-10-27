/*
	ETFilter.m
	
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

#import <EtoileFoundation/ETFilter.h>


@implementation ETFilter

/** Returns a new filter connected to an existing filter. */
- (id) initWithFilter: (ETFilter *)filter
{
	return [self initWithObject: filter];
}

/** <init /> Returns a new filter by chaining filters passed in parameter. */
- (id) initWithCollection: (id <ETCollection>)filters
{
	return [super initWithCollection: filters];
}

/** Returns the filter following the receiver in the filter chain. */
- (ETFilter *) nextFilter
{
	return (ETFilter *)[self nextObject];
}

/** Sets the filter following the receiver in the filter chain. 
	Take note this method discards the existing next filter and the whole 
	filter chain connected to it. If you want to reconnect the existing 
	next filter, it's up to you to handle it. */
- (void) setNextFilter: (ETFilter *)filter
{
	[self setNextObject: filter];
}

/** Returns the filter terminating the filter chain the receiver belongs
	to. In other words, returns the first filter that has no next filter 
	connected to it. */
- (ETFilter *) lastFilter
{
	return (ETFilter *)[self lastObject];
}

/** Returns the selector uses for filter processing which is equal to -render:
	if you don't override the method. 
	Try also to override -render: if you override this method, so you your 
	custom filters can be used in other filter chains in some sort of fallback
	mode. */
- (SEL) filterSelector
{
	return @selector(render:);
}

/** Process object with the filter chain by passing the parameter from 
	filter-to-filter with the order resulting from calling -nextFilter on each
	filter.
	When overriding this method, you should usually handle the receiver 
	rendering before delegating it to the rest of the filter chain. This 
	implies using return [super render: object] at the end of the overriden 
	method. */
- (id) render: (id)object
{
	return [[self nextFilter] render: object];
}

@end
