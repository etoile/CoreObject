/*
	ETXMLString.m

	Copyright (C) 2006 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  15/05/2006

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

#import "ETXMLString.h"
#import "ETXMLParser.h"
#import "Macros.h"

@implementation ETXMLString

- (id) initWithXMLParser: (ETXMLParser*)aParser
                  parent: (id <ETXMLParserDelegate>)aParent
                     key: (id)aKey
{
	self = [super initWithXMLParser: aParser
	                         parent: aParent
	                            key: aKey];
	if (nil == self)
	{
		return nil;
	}
	value = nil;
	return self;
}

- (void) notifyParent
{
	if(value != nil)
	{
		id oldValue = value;
		value = [unescapeXMLCData(value) retain];
		[oldValue release];		
	}
	[super notifyParent];
}

- (void) characters: (NSString *)aString
{
	if(value == nil)
	{
		value = [aString retain];
	}
	else
	{
		id new = [[value stringByAppendingString:aString] retain];
		[value release];
		value = new;
	}
}

@end
