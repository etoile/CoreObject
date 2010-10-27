/*
	ETXMLParserDelegate.h

	Copyright (C) 2004 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  Wed Apr 28 2004

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
 * Helper function for escaping XML character data.
 */
static inline NSMutableString * escapeXMLCData(NSString *_XMLString)
{
	if(_XMLString == nil)
	{
		return [NSMutableString stringWithString:@""];
	}
	NSMutableString * XMLString = [NSMutableString stringWithString:_XMLString];
	[XMLString replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"'" withString:@"&apos;" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0,[XMLString length])];
	return XMLString;
}

/**
 * Helper function for unescaping XML character data.
 */
static inline NSMutableString * unescapeXMLCData(NSString *_XMLString)
{
	if(_XMLString == nil)
	{
		return [NSMutableString stringWithString:@""];
	}
	NSMutableString * XMLString = [NSMutableString stringWithString:_XMLString];
	[XMLString replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"&apos;" withString:@"'" options:0 range:NSMakeRange(0,[XMLString length])];
	[XMLString replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0,[XMLString length])];
	return XMLString;
}

/**
 * The ETXMLWriting protocol is implemented by any object which consumes
 * SAX-like events, either from a parser or from some other data source.
 */
@protocol ETXMLWriting <NSObject>
/**
 * Called by the parser whenever character data is parsed.  The parser will 
 * attempt to compromise between getting the data to the handler as soon as 
 * possible, and avoiding calling this too frequently.  Typically, this will 
 * either be passed a complete CDATA run in one go, or it will be passed the 
 * longest available CDATA section in the current parse buffer.
 */
- (void)characters: (NSString *)_chars;
/**
 * Called whenever a new XML element is started.  Attributes are passed in a 
 * dictionary in the same key-value pairs in the XML source.
 */
- (void)startElement: (NSString *)_Name
          attributes: (NSDictionary*)_attributes;
/**
 * Called whenever an XML element is terminated.  Short form XML elements
 * (e.g.  &lt;br /&gt;) will cause immediate calls to the start and end element
 * methods in the delegate.
 */
- (void)endElement: (NSString *)_Name;
@end
/**
 * The ETXMLParserDelegate protocol is a formal protocol that must be 
 * implemented by classes used as delegates for XML parsing.
 */
@protocol ETXMLParserDelegate <ETXMLWriting>
/**
 * Used to set the associated parser.
 *
 * Note: It might be better to parse the parser in to the other methods as an 
 * argument (e.g. characters:fromParser:).  Anyone wishing to make this change
 * should be aware that it will require a significant amount of refactoring in
 * the XMPP code.
 */
- (void) setParser: (id)XMLParser;
/**
 * Sets the parent.  When the delegate has finished parsing it should return 
 * control to the parent by setting the delegate in the associated parser.
 */
- (void) setParent: (id)newParent;
@end
