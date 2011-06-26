/*
	ParserTest.m

	Copyright (C) 2007 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  2007

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
#import "ETXMLParser.h"
#import "ETXMLParserDelegate.h"

@interface ParserTest :NSObject <ETXMLParserDelegate>
@end
@implementation ParserTest
- (void) characters:(NSString *)_chars
{
	NSLog(@"CDATA: %@", _chars);
}
- (void)startElement:(NSString *)_Name
          attributes:(NSDictionary*)_attributes
{
	NSLog(@"Starting element %@ with attributes %@", _Name, _attributes);
}
- (void)endElement:(NSString *)_Name
{
	NSLog(@"Ending element %@", _Name);
}
- (void) setParser:(id) XMLParser {}
- (void) setParent:(id) newParent {}
@end

int main(int argc, char ** argv)
{
	[NSAutoreleasePool new];
	ETXMLParser * parser = [ETXMLParser parserWithContentHandler:[ParserTest new]];
	//Uncomment to test parser as an SGML parser.
	//[parser setMode:sgml];
	for(unsigned int i=1 ; i<argc ; i++)
	{
		[parser parseFromSource: [NSString stringWithUTF8String: argv[i]]];
	}
	return 0;
}
