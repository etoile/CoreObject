/*
	ETXMLParser.m

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

#import "ETXMLParser.h"
#import "ETXMLParserDelegate.h"

#define SUCCESS 0
#define FAILURE -1
#define TEMPORARYFAILURE 1

@implementation ETXMLParser

+ (id) parserWithContentHandler: (id <ETXMLWriting>)_contentHandler
{
	return [[[ETXMLParser alloc] initWithContentHandler:_contentHandler] autorelease];
}

- (id) initWithContentHandler: (id <ETXMLWriting>)_contentHandler
{
	[self init];
	[self setContentHandler:_contentHandler];
	return self;
}

- (id) init
{
	delegate = nil;
	buffer = [[NSMutableString stringWithString:@""] retain];
	openTags = [[NSMutableArray alloc] init];
	mode = PARSER_MODE_XML;
	state = notag;
	return [super init];
}

- (id) setContentHandler: (id <ETXMLWriting>)_contentHandler
{
	[delegate release];
	delegate = [_contentHandler retain];
	if ([delegate conformsToProtocol: @protocol(ETXMLParserDelegate)])
	{
		[(id)delegate setParser: self];
	}
	return self;
}

- (int) parseFrom: (int)_index to: (unichar)_endCharacter
{
	int end = [buffer length];
	//TODO:  Make this a bit less slow.
	while(_index < end && [buffer characterAtIndex:_index] != _endCharacter)
	{
		_index++;
	}
	if(_index < end)
	{
		return _index;
	}
	return -1;
}

- (int) ignoreWhiteSpaceFrom: (int)_index
{
	int end = [buffer length];
	if(_index >= end)
	{
		return -1;
	}
	unichar character = [buffer characterAtIndex:_index];
	while(isspace(character))
	{
		_index++;
		if(_index >= end)
		{
			break;
		}
		character = [buffer characterAtIndex:_index];
	}
	if(_index < end)
	{
		return _index;
	}
	return -1;	
}

#define ISCOMMENT(tag) (([tag length] > 2) && [[tag substringToIndex:3] isEqualToString:@"!--"])

- (int) parseTagFrom: (int *)_index 
               named: (NSMutableString *)_name 
      withAttributes:(NSMutableDictionary*)_attributes
{
#define RETURN(x) (*_index) = current ; return x
#define SKIPWHITESPACE 	start = [self ignoreWhiteSpaceFrom:start]; if(start == -1) {RETURN(TEMPORARYFAILURE);} 	current = start;
#define SEARCHTO(x) current = [self parseFrom:start to:x];if(current == -1){RETURN(TEMPORARYFAILURE);}
#define CURRENTSTRING [buffer substringWithRange:NSMakeRange(start,MIN((current - start), ([buffer length] - 1)))]

	int start = *_index;
	int current = -1;
	int bufferLength = [buffer length];
	NSString * attributeName;
	NSString * attributeValue;
	unichar currentChar;

	SKIPWHITESPACE;
	//Skip a leading '<' if there is one
	currentChar = [buffer characterAtIndex:start];
	while(
		  start < bufferLength && 
		  (
		   currentChar == '<' || 
		   currentChar == '/' 
		   )
		  )
	{
		start++;
		currentChar = [buffer characterAtIndex:start];
	}
	SKIPWHITESPACE;
//TODO: Parse <?xml and <!DOCTYPE things with this.
	//get the name
	currentChar=[buffer characterAtIndex:current];
	while(current < (bufferLength-1) && !isspace(currentChar) && currentChar != '>' && currentChar != '/')
	{
		current++;
		currentChar=[buffer characterAtIndex:current];		
		if(current - start == 8
			&&
			[CURRENTSTRING isEqualToString:@"![CDATA["])
		{
			[_name setString:CURRENTSTRING];
			RETURN(SUCCESS);
		}
	}
	[_name setString:CURRENTSTRING];
	if(ISCOMMENT(_name))
	{
		SEARCHTO('>');
		state = incdata;
		RETURN(SUCCESS);
	}
	start = current;
	//Skip to the end or the first attribute 
	SKIPWHITESPACE;
	while([buffer characterAtIndex:start] != '>' && start+1 < bufferLength && [buffer characterAtIndex:(start + 1)] != '>')
	{
		unichar quote;
		SEARCHTO('=');
		attributeName = CURRENTSTRING;
		current++;
		if((unsigned int)current >= [buffer length])
		{
			return TEMPORARYFAILURE;
		}
		quote = [buffer characterAtIndex:current];
		BOOL quotedAttribute = (quote == '"' || quote == '\'');
		if(!quotedAttribute)
		{
			if(mode == PARSER_MODE_XML)
			{
				RETURN(FAILURE);
			}
			else
			{
				quote = ' ';
				current--;
			}
		}
		current++;
		start = current;
		if(quotedAttribute)
		{
			SEARCHTO(quote);			
		}
		else
		{
			int end = [buffer length];
			//TODO:  Make this a bit less slow.
			while(current < end && 
				  [buffer characterAtIndex:current] != quote
				  &&
				  [buffer characterAtIndex:current] != '>')
			{
				current++;
			}
			if(current >= end)
			{
				return TEMPORARYFAILURE;
			}
		}
		attributeValue = CURRENTSTRING;
		[_attributes setValue:unescapeXMLCData(attributeValue) forKey:attributeName];
		start = current;
		if(quotedAttribute)
		{
			start++;
		}
		SKIPWHITESPACE;
	}
	if([buffer characterAtIndex:start] == '>' || (start+1 < bufferLength && [buffer characterAtIndex:(start + 1)] == '>'))
	{
		RETURN(SUCCESS);
	}
	RETURN(TEMPORARYFAILURE);
#undef RETURN
#undef CURRENTSTRING
#undef SKIPWHITESPACE
#undef SEARCHTO
}

- (BOOL) parseFromSource: (NSString *)data
{
//Macro to end parsing neatly if a particular condition is met
//Invoking this stores the unparsed buffer and returns YES.
#define ENDPARSINGIF(x) if(x) { [buffer deleteCharactersInRange:NSMakeRange(0,lastSuccessfullyParsed)]; /*NSLog(@"Unparsed: '%@'", buffer);*/ return YES;}
#define SKIPTO(x) currentIndex = [self parseFrom:currentIndex to:x]; ENDPARSINGIF(currentIndex == -1);
#define CURRENTSTRING [buffer substringWithRange:NSMakeRange(lastSuccessfullyParsed,currentIndex - lastSuccessfullyParsed)]
						
	int currentIndex = 0;
	int lastSuccessfullyParsed = 0;
	int bufferLength;
	if(state == broken)
	{
		return NO;
	}
	//NSLog(@"Old XML: %@", buffer);	
	[buffer appendString:data];
	//NSLog(@"XML: %@", buffer);
	bufferLength = [buffer length];
	while(currentIndex < bufferLength)
	{
		unichar currentChar;
		//If we have not yet parsed a tag, we are looking for either:
		//1) An <?xml... tag
		//2) A <!DOCTYPE... tag
		//3) A root tag.
		//Currently, we ignore anything other than case 3.
		switch (state)
		{
			case notag:
			{
				currentIndex = [self ignoreWhiteSpaceFrom:currentIndex];
				if(currentIndex < 0)
				{
					[buffer setString:@""];
					return YES;
				}
				SKIPTO('<');
				currentIndex++;
				state = intag;
				ENDPARSINGIF(currentIndex >= bufferLength);
				currentChar = [buffer characterAtIndex:currentIndex];
				//Case 2.
				//BUG: <?xml...?> initial tags containing the > tag will break this parser.
				if(currentChar == '!' || currentChar == '?')
				{
					//Skip to the end of the tag
					SKIPTO('>');
					state = notag;
					lastSuccessfullyParsed = currentIndex;
					currentIndex++;
				} 
				else
				{
					lastSuccessfullyParsed = currentIndex;
				}
				break;
			}
			case intag:
			{
				NSMutableString * tagName = [[NSMutableString alloc] init];
				NSMutableDictionary * tagAttributes = [[NSMutableDictionary alloc] init];
				BOOL openTag = YES;
				int parseSuccess;
				
				if([buffer characterAtIndex:currentIndex] == '<')
				{
					currentIndex++;
					if(currentIndex >= bufferLength)
					{
						[buffer deleteCharactersInRange:NSMakeRange(0,currentIndex)];
						return YES;
					}
				}
				if([buffer characterAtIndex:currentIndex] == '/')
				{
					openTag = NO;
					currentIndex++;
				}
				parseSuccess = [self parseTagFrom:&currentIndex named:tagName withAttributes:tagAttributes];
				switch(parseSuccess)
				{
					case SUCCESS:
						if(openTag)
						{
							if(!ISCOMMENT(tagName))
							{
								//Special case for stupid CDATA things.
								if([tagName isEqualToString:@"![CDATA["])
								{
									lastSuccessfullyParsed = currentIndex;
									state = instupidcdata;
									break;
								}
								else
								{
									NS_DURING
									{
										//NSLog(@"<%@> (%@)", tagName, tagAttributes);
										[delegate startElement:tagName attributes:tagAttributes];
									}
									NS_HANDLER
									{
										NSLog(@"An exception occured while starting element %@.  Write better code!  Exception: %@", tagName, [localException reason]);	
									}
									NS_ENDHANDLER
									if(mode == PARSER_MODE_XML)
									{
										[openTags addObject:tagName];
									}
									state = incdata;
								}
							}
						}
						currentChar = [buffer characterAtIndex:currentIndex];
						if(currentChar == '/' || !openTag)
						{
							if(mode == PARSER_MODE_XML)
							{
								if([openTags count] == 0 || ![[openTags lastObject] isEqualToString:tagName])
								{
									state = broken;
									NSLog(@"Tag %@ closed, but last tag opened was %@.", tagName, [openTags lastObject]);
									return NO;
								}
								[openTags removeLastObject];
							}
							NS_DURING
							{
								//NSLog(@"</%@> (%@)", tagName, openTags);
								[delegate endElement:tagName];
							}
							NS_HANDLER
							{
								NSLog(@"An exception (%@) occured while ending element %@.  Write better code!", [localException reason], tagName);
							}
							NS_ENDHANDLER
							currentIndex++;
							state = incdata;
						}
						currentIndex--;
						SKIPTO('>');
						currentIndex++;
						lastSuccessfullyParsed = currentIndex;
						break;
					case TEMPORARYFAILURE:
						ENDPARSINGIF(YES);
					case FAILURE:
						state = broken;
						return NO;
					default:
						NSLog(@"parseTagFrom returned %d, which is just plain wrgon.", parseSuccess);
						state = broken;
						return NO;
				}
				[tagName release];
				[tagAttributes release];
				break;
			}
			case incdata:
			{
				NSString * cdata;
				SKIPTO('<');
				if (currentIndex != lastSuccessfullyParsed)
				{
					cdata = CURRENTSTRING;
					//If cdata contains a > (close tag) then we are parsing nonsense, not XML.
					if([cdata rangeOfString:@">"].location != NSNotFound)
					{
						[cdata release];
						state = broken;
						return NO;
					}
					NS_DURING
					{
						[delegate characters:cdata];
					}
					NS_HANDLER
					{
						NSLog(@"An exception occured while adding CDATA: \n'%@'\n.  Write better code!", cdata);
					}
					NS_ENDHANDLER
					lastSuccessfullyParsed = currentIndex;
				}
				state = intag;
				break;
			}
			case instupidcdata:
			{
				NSString * cdata = [buffer substringFromIndex:lastSuccessfullyParsed];
				NSRange cdataEnd = [cdata rangeOfString:@"]]>"];
				if(cdataEnd.location == NSNotFound)
				{				
					NS_DURING
					{
						[delegate characters:cdata];
					}
					NS_HANDLER
					{
						NSLog(@"An exception occured while adding CDATA: \n'%@'\n.  Write better code!", cdata);
					}
					NS_ENDHANDLER
					currentIndex = bufferLength;
				}
				else
				{
					NS_DURING
					{
						[delegate characters:[cdata substringToIndex:cdataEnd.location]];
					}
					NS_HANDLER
					{
						NSLog(@"An exception occured while adding CDATA: \n'%@'\n.  Write better code!", cdata);
					}
					NS_ENDHANDLER
					currentIndex += cdataEnd.location + 3;
					state = notag;
				}
				lastSuccessfullyParsed = currentIndex;
				break;
			}
			default:
				NSLog(@"Parser in undefined state.");
		}
	}
	[buffer setString:@""];
	return YES;
#undef CURRENTSTRING
#undef ENDPARSINGIF
#undef SKIPTO
}

- (void) setMode: (enum MarkupLanguage)aMode
{
	mode = aMode;
}
- (void)dealloc
{
	[buffer release];
	[super dealloc];
}

@end
