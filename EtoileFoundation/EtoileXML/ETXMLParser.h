/*
	ETXMLParser.h

	Copyright (C) 2004 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  Wed Apr 28 2004.

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

@protocol ETXMLWriting;

/**
 * An XML stream parse class.  This parser is statefull, and will cache any 
 * unparsed data.  Messages are fired off to the delegate for start and end tags
 * as well as character data.  
 *
 * This class might more accurately be called ETXMLScanner or ETXMLTokeniser
 * since the actual parsing is handled by the delegate.
 */
@interface ETXMLParser : NSObject 
{
	NSMutableString *buffer;
	id <ETXMLWriting> delegate;
	int depth;
	NSMutableArray *openTags;
	enum {notag, intag, inattribute, incdata, instupidcdata, incomment, broken} state;
	enum MarkupLanguage {PARSER_MODE_XML, PARSER_MODE_SGML}  mode;
}
/**
 * Create a new parser with the specified delegate.
 */
+ (id) parserWithContentHandler: (id <ETXMLWriting>)_contentHandler;
/**
 * Initialise a new parser with the specified delegate.
 */
- (id) initWithContentHandler: (id <ETXMLWriting>)_contentHandler;
/**
 * Set the class to receive messages from input data.  Commonly used to delegate
 * handling child elements to other classes, or to pass control back to the 
 * parent afterwards.
 */
- (id) setContentHandler: (id <ETXMLWriting>)_contentHandler;
/**
 * Parse the given input string.  This, appended to any data previously supplied
 * using this method, must form a (partial) XML document.  This function returns
 * NO if an error occurs while parsing.
 */
- (BOOL) parseFromSource: (NSString *)data;
/**
 * Switch between parsing modes.  Acceptable values are PARSER_MODE_XML and 
 * PARSER_MODE_SGML.  When in SGML mode, open tags do not have to have 
 * corresponding closing tags, allowing things like &lt;br&gt; to exist.  XML
 * is the default.
 */
- (void) setMode: (enum MarkupLanguage)aMode;
@end
