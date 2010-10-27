/*
	ETXMLNode.m

	Copyright (C) 2004 David Chisnall

	Author:  David Chisnall <csdavec@swan.ac.uk>
	Date:  Thu Apr 22 2004

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

#import "ETXMLNode.h"
#import "ETXMLParser.h"
#import "Macros.h"
#include <stdio.h>

//TODO: Generalise this as a filtered array enumerator
@interface ETXMLNodeChildEnumerator : NSEnumerator
{
	unsigned int index;
	NSArray * elements;
}
+ (ETXMLNodeChildEnumerator *) enumeratorWithElements: (NSArray *)anArray;
@end

@implementation ETXMLNodeChildEnumerator

- (ETXMLNodeChildEnumerator *) initWithElements: (NSArray *)anArray
{
	SUPERINIT;
	elements = [anArray retain];
	return self;
}

+ (ETXMLNodeChildEnumerator *) enumeratorWithElements: (NSArray *)anArray
{
	return [[ETXMLNodeChildEnumerator alloc] initWithElements:anArray];
}

- (NSArray *) allObjects
{
	NSMutableArray * elementsLeft = AUTORELEASED(NSMutableArray);
	ETXMLNode * nextObject;
	while((nextObject = [self nextObject]) != nil)
	{
		[elementsLeft addObject:nextObject];
	}
	return elementsLeft;
}

- (id) nextObject
{
	unsigned int count = [elements count];
	while(index < count)
	{
		id nextObject = [elements objectAtIndex:index++];
		if([nextObject isKindOfClass:[ETXMLNode class]])
		{
			return nextObject;
		}
	}
	return nil;
}

@end

@implementation ETXMLNode

- (id) init
{
	elements = [[NSMutableArray alloc] init];
	plainCDATA = [[NSMutableString alloc] init];
	childrenByName = [[NSMutableDictionary alloc] init];
	return [super init];
}

+ (id) ETXMLNodeWithType: (NSString *)type
{
	return [[[ETXMLNode alloc] initWithType:type]autorelease];
}

+ (id) ETXMLNodeWithType: (NSString *)type attributes: (NSDictionary *)_attributes
{
	return [[[ETXMLNode alloc] initWithType:type attributes:_attributes] autorelease];
}

- (id) initWithType: (NSString *)type
{
	return [self initWithType:type attributes:nil];
}

- (id) initWithType: (NSString *)type attributes: (NSDictionary *)_attributes
{
	nodeType = [type retain];
	attributes = [_attributes retain];
	return [self init];
}

//Default implementation.  Returns parse control to parent at end of node.
- (void) endElement: (NSString *)_Name
{
/*	NSLog(@"Ending Element %@", _Name);*/
	if([_Name isEqualToString:nodeType])
	{
		[parser setContentHandler:parent];
		[parent addChild:(id)self];
	}
}

- (void) startElement: (NSString *)_Name
           attributes: (NSDictionary *)_attributes
{
/*	NSLog(@"Starting element %@ with attributes:", _Name);
	NSEnumerator * enumerator = [_attributes keyEnumerator];
	NSString * key = [enumerator nextObject];
	while(key != nil)
	{
		NSLog(@"%@=%@", key, [_attributes objectForKey:key]);
		key = [enumerator nextObject];
	}*/
	id newNode = [[ETXMLNode alloc] initWithType:_Name attributes:_attributes];
	[newNode setParser:parser];
	[newNode setParent:self];
	[parser setContentHandler:newNode];		
}


- (void)characters:(NSString *)_chars
{
	NSString * plainChars = unescapeXMLCData(_chars);
	id lastElement = [elements lastObject];
	//If the last element is a string
	if([lastElement isKindOfClass:[NSString class]])
	{
		NSString * combinedString = [lastElement stringByAppendingString:plainChars];
		[elements removeLastObject];
		[elements addObject:combinedString];
	}
	else
	{
		[elements addObject:plainChars];
	}
	[plainCDATA appendString:plainChars];
}

- (NSString *) type
{
	return nodeType;
}

- (NSString *) stringValueWithIndent:(int)indent
{
	//Open tag
	NSMutableString * XML = [NSMutableString stringWithFormat:@"<%@",nodeType];
	//Number of tabs to indent
	NSMutableString * indentString;
	if(indent >= 0)
	{
		indentString = [NSMutableString stringWithString:@"\n"];
	}
	else
	{
		indentString = [NSMutableString string];
	}
	
	for(int i=0 ; i<indent ; i++)
	{
		[indentString appendString:@"\t"];
	}
	
	//Add attributes
	if(attributes != nil)
	{
		NSEnumerator *enumerator = [attributes keyEnumerator];		
		NSString* key;
		while ((key = (NSString*)[enumerator nextObject])) 
		{
			[XML appendString:[NSString stringWithFormat:@" %@=\"%@\"",key, escapeXMLCData([attributes objectForKey:key])]];
		}
	}
	
	//If we just have CDATA (no children)
	if([elements count] > 0 && [childrenByName count] == 0)
	{
		[XML appendString:@">"];
		[XML appendString:escapeXMLCData([NSMutableString stringWithString:plainCDATA])];
		[XML appendString:[NSString stringWithFormat:@"</%@>",nodeType]];
	}
	else if([elements count] > 0)
	{
		NSMutableString * childIndentString = [NSMutableString stringWithString:indentString];

		//Children are indented one more tab than parents
		if(indent > 0)
		{
			[childIndentString appendString:@"\t"];
		}
		//End the start element
		[XML appendString:@">"];
		
		Class stringClass = NSClassFromString(@"NSString");
		//Add children and CDATA
		FOREACHI(elements, element)
		{
			//Indent the child element
			[XML appendString:childIndentString];
			if([element isKindOfClass:stringClass])
			{
				[XML appendString:escapeXMLCData(element)];
			}
			else
			{
				if(indent < 0)
				{
					[XML appendString:[element stringValueWithIndent:indent]];					
				}
				else
				{
					[XML appendString:[element stringValueWithIndent:indent + 1]];
				}
			}
		}
		/* Remove last '\t' */
		if (indent > 0)
		{
			[indentString deleteCharactersInRange: NSMakeRange([indentString length]-1, 1)];
		}
		[XML appendString:indentString];
		[XML appendString:[NSString stringWithFormat:@"</%@>",nodeType]];
	}
	else
	{
		[XML appendString:@"/>"];
	}
	return XML;
}


- (NSString *) stringValue
{
	return [self stringValueWithIndent:0];
}
- (NSString *) unindentedStringValue
{
	return [self stringValueWithIndent:-1];
}

- (void) addChild: (id)anElement
{
	if(![anElement isKindOfClass:[ETXMLNode class]])
	{
		if([anElement respondsToSelector:@selector(xmlValue)])
		{
			//Indirect call to eliminate compiler warning that selector might not be found.
			anElement = [anElement performSelector:@selector(xmlValue)];
		}
		else
		{
			return;
		}
	}
	children++;
	id lastElement = [elements lastObject];
	//If there is nothing other than white space between this child and the last one, the XML specification instructs us to ignore the whitespace
	if([lastElement isKindOfClass:[NSString class]] && [[lastElement stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""])
	{
		[elements removeLastObject];
	}
	[elements addObject:anElement];
	NSString * childType = [anElement type];
	NSMutableSet * childrenWithName = [childrenByName objectForKey:childType];
	if(childrenWithName == nil)
	{
		childrenWithName = [NSMutableSet set];
		[childrenByName setObject:childrenWithName forKey:childType];
	}
	[childrenWithName addObject:anElement];
}

- (void) addCData: (id)newCData
{
	if([newCData isKindOfClass:[NSString class]])
	{
		[self characters:newCData];
	}
	else if([newCData respondsToSelector:@selector(stringValue)])
	{
		[self characters:[newCData stringValue]];
	}
}

//TODO: Implement hash: and isEqual so that this set actually works...
- (NSArray *) elements
{
	return elements;
}

- (NSSet *) getChildrenWithName:(NSString *)_name
{
	return [childrenByName objectForKey:_name];
}

- (unsigned int) children
{
	return children;
}

- (NSEnumerator *) childEnumerator
{
	return [ETXMLNodeChildEnumerator enumeratorWithElements:elements];
}


- (void) setParser: (id)XMLParser
{
	//Don't retain, since we can't release.
	parser = XMLParser;
}

- (void) setParent: (id)newParent
{
	parent = newParent;
}

- (NSString *) get: (NSString *)attribute
{
	return (NSString*)[attributes objectForKey:attribute];
}

- (void) set: (NSString *)attribute to: (NSString *) value
{
	if(attributes == nil)
	{
		attributes = [[NSMutableDictionary alloc] init];
	}
	//If we were passed an immutable object as the constructor, we need to make it mutable
	if(![attributes isMemberOfClass:[NSMutableDictionary class]])
	{
		id oldAttributes = attributes;
		attributes = [[NSMutableDictionary dictionaryWithDictionary:attributes] retain];
		[oldAttributes release];
	}	
	[attributes setObject:value forKey:attribute];
}

- (NSString *) cdata
{
	return plainCDATA;
}

- (void) setCData: (NSString *)newCData
{
	[plainCDATA release];
	plainCDATA = [newCData retain];
	for(unsigned int i=0 ; i < [elements count] ; i++)
	{
		while(i < [elements count] && [[elements objectAtIndex:i] isKindOfClass:[NSString class]])
		{
			[elements removeObjectAtIndex:i];
		}
	}
	[elements addObject:newCData];
}

- (void) dealloc
{
	[elements removeAllObjects];
	[elements release];
	[attributes release];
	[plainCDATA release];
	[nodeType release];
	[childrenByName release];
	[super dealloc];
}

@end

