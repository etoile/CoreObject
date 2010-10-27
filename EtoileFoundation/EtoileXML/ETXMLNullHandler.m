/*
	ETXMLNullHandler.m

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

#import "ETXMLNullHandler.h"
#import "ETXMLParser.h"
#import "Macros.h"

@implementation ETXMLNullHandler
- (id) initWithXMLParser: (id)aParser 
                  parent: (id <ETXMLParserDelegate>)aParent 
                     key: (id)aKey
{
	SUPERINIT
	value = [self retain];
	[aParser setContentHandler:self];
	[self setParser:aParser];
	[self setParent:aParent];
	key = [aKey retain];
	return self;
}

- (id) init
{
	return [self initWithXMLParser: nil
	                        parent: nil
	                           key: nil];
}

- (void) setParser: (id)XMLParser
{
	parser = XMLParser;
}

- (void) setParent: (id)newParent
{
	parent = newParent;
}

- (void) characters: (NSString *)_chars
{
	//Ignore cdata
}

- (void) startElement: (NSString *)_Name
           attributes: (NSDictionary*)_attributes
{
	depth++;
}

- (void) endElement: (NSString *)_Name
{
	depth--;
	if(depth == 0)
	{
		[parser setContentHandler:parent];
		[self notifyParent];
		[self release];
	}
}
- (void) addChild: (id)aChild forKey: (id)aKey
{
	NSString * childSelectorName = [NSString stringWithFormat:@"add%@:", aKey];
	SEL childSelector = NSSelectorFromString(childSelectorName);
	if([self respondsToSelector:childSelector])
	{
		[self performSelector:childSelector withObject:aChild];
	}
	else
	{
		//NSLog(@"Unrecognised XML child type: %@", aKey);
	}
}

- (void) notifyParent
{
	if(key != nil && [parent respondsToSelector:@selector(addChild:forKey:)])
	{
		[(id)parent addChild:value forKey:key];
		//NSLog(@"Setting value: %@ for key: %@ in %@", value, key, parent);
	}
	[self release];
}

- (void) dealloc
{
	[key release];
	[super dealloc];
}

@end
