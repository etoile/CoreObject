/*
	ETXMLDeclaration.m

	Copyright (C) 2007 Yen-Ju Chen

	Author:  Yen-Ju Chen <yjchenx gmail>
	Date:  Thu Jul 12 2007

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

#import "ETXMLDeclaration.h"
#import "Macros.h"

@implementation ETXMLDeclaration

+ (id) ETXMLDeclaration
{
	ETXMLDeclaration *decl = [[ETXMLDeclaration alloc] initWithType: @"" attributes: [NSDictionary dictionaryWithObjectsAndKeys: @"version", @"1.0", @"encoding", @"UTF-8", nil]];
	return [decl autorelease];
}

- (NSString *) stringValueWithIndent:(int)indent
{
	/* Because this is the first element, we don't really care about indent */

	NSMutableString * XML = [NSMutableString stringWithFormat:@"<?xml"];

	/* version */
	NSString *value = [attributes objectForKey: @"version"];
	if (value == nil)
		value = @"1.0";

	[XML appendString: [NSString stringWithFormat: @" version=\"%@\"", value]];

	/* encoding */
	value = [attributes objectForKey: @"encoding"];
	if (value == nil)
		value = @"UTF-8";

	[XML appendString: [NSString stringWithFormat: @" encoding=\"%@\"", value]];

	/* standalone*/
	value = [attributes objectForKey: @"standalone"];
	if ((value != nil) && ([value isEqualToString: @"yes"] || [value isEqualToString: @"no"]))
	{
		[XML appendString: [NSString stringWithFormat: @" standalone=%@", value]];
	}

	/* We close it */
	[XML appendString: @"?>\n"];


	if([elements count] > 0)
	{
		//Add children (not CDATA)
		FOREACHI(elements, element)
		{
			if([element isKindOfClass: [ETXMLNode class]])
			{
				[XML appendString:[element stringValueWithIndent:indent]];
			}
		}
	}
	return XML;
}

- (void) addCData: (id)newCData
{
	/* We do nothing here */
}

- (void) setParent: (id) newParent
{
	/* We cannot have parent */
}

- (void) setCData: (NSString *)newCData
{
	/* We do nothing here */
}

- (void) dealloc
{
	[super dealloc];
}

@end

