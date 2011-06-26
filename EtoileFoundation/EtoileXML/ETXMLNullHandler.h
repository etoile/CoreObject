/*
	ETXMLNullHandler.h

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

#import <Foundation/Foundation.h>
#import <EtoileXML/ETXMLParserDelegate.h>

@class ETXMLParser;

/**
 * The ETXMLNullHandler class serves two purposes.  First, it is used when
 * parsing to ignore an XML element and all of its children.  It simply 
 * maintains a count of the depth, and ignores everything passed to it.
 *
 * The second use is as a superclass for other XML parser delegates.  The class
 * implements the required functionality for a parser delegate, and so can be
 * easily extended through subclassing.
 */
@interface ETXMLNullHandler : NSObject <ETXMLParserDelegate> 
{
	unsigned int depth;
	id parser;
	id<ETXMLParserDelegate> parent;
	id key;
	id value;
}
/**
 * Create a new handler for the specified parent.  When the next element and 
 * all children have been handled (ignored), control will be returned to the 
 * parent object.  
 *
 * The key is used to pass the parsed object (if not nil) to the parent.  The
 * parent's -add{key}: method will be called with the value of this object's
 * 'value' instance variable when -notifyParent: is called.  This is only
 * relevant to sub-classes.
 */
- (id) initWithXMLParser: (ETXMLParser*)aParser 
                  parent: (id <ETXMLParserDelegate>)aParent 
                     key: (id)aKey;
/**
 * Dynamic dispatch method that calls [self add{aChild}:aKey] if the object
 * responds to add{aChild}:.  This is similar to the KVC mechamism, but used
 * instead so subclasses do not have to be fully KVC compliant.
 */
- (void) addChild: (id)aChild forKey: (id)aKey;
/**
 * Pass the instance variable 'value' up to the parent.  
 */
- (void) notifyParent;
@end
