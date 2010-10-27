/*
	ETXMLXHTML-IMParser.m

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

#import "ETXMLXHTML-IMParser.h"
#import "ETXMLParser.h"
#import "Macros.h"

#define TRIM(x) [x stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]

/* find the attribute regardless the case */
static inline id attributeForCaseInsensitiveKey(NSDictionary *attrs, id key)
{
	return [attrs objectForKey:[key lowercaseString]];
}

#ifdef GNUSTEP
#define NSUnderlineStyleSingle NSSingleUnderlineStyle
#define NSStrikethroughStyleAttributeName @"NSStrikethroughStyleAttributeName"
#endif

static inline NSColor * colourFromCSSColourString(NSString *aColour)
{
	const char * colourString = [aColour UTF8String];
	int r,g,b;
	if(sscanf(colourString, "#%2x%2x%2x", &r, &g, &b) == 3 || sscanf(colourString, "#%2X%2X%2X", &r, &g, &b) == 3)
	{
		return [NSColor colorWithCalibratedRed:((float)r)/255.0f
										 green:((float)g)/255.0f
										  blue:((float)b)/255.0f
										 alpha:1.0f];
	}
	if(sscanf(colourString, "#%1x%1x%1x", &r, &g, &b) == 3 || sscanf(colourString, "#%1X%1X%1X", &r, &g, &b) == 3)
	{
		return [NSColor colorWithCalibratedRed:((float)r)/15.0f
										 green:((float)g)/15.0f
										  blue:((float)b)/15.0f
										 alpha:1.0f];
	}
	if(sscanf(colourString, "rgb( %d%% , %d%% , %d%% )", &r, &g, &b))
	{
		return [NSColor colorWithCalibratedRed:((float)r)/100.0f
										 green:((float)g)/100.0f
										  blue:((float)b)/100.0f
										 alpha:1.0f];
	}
	if(sscanf(colourString, "rgb( %d , %d , %d )", &r, &g, &b))
	{
		return [NSColor colorWithCalibratedRed:((float)r)/255.0f
										 green:((float)g)/255.0f
										  blue:((float)b)/255.0f
										 alpha:1.0f];
	}
	if([aColour isEqualToString:@"aqua"])
	{
		return [NSColor cyanColor];
	}
	if([aColour isEqualToString:@"black"])
	{
		return [NSColor blackColor];
	}
	if([aColour isEqualToString:@"blue"])
	{
		return [NSColor blueColor];
	}
	if([aColour isEqualToString:@"fuchsia"])
	{
		return [NSColor magentaColor];
	}
	if([aColour isEqualToString:@"gray"])
	{
		return [NSColor grayColor];
	}
	if([aColour isEqualToString:@"green"])
	{
		return [NSColor greenColor];
	}
	if([aColour isEqualToString:@"lime"])
	{
		return [NSColor colorWithCalibratedRed:0.0f
										 green:1.0f
										  blue:0.0f
										 alpha:1.0f];
	}
	if([aColour isEqualToString:@"maroon"])
	{
		return [NSColor colorWithCalibratedRed:0.5f
										 green:0.0f
										  blue:0.0f
										 alpha:1.0f];
	}
	if([aColour isEqualToString:@"navy"])
	{
		return [NSColor colorWithCalibratedRed:0.0f
										 green:0.0f
										  blue:0.5f
										 alpha:1.0f];
	}
	if([aColour isEqualToString:@"olive"])
	{
		return [NSColor colorWithCalibratedRed:0.0f
										 green:0.5f
										  blue:0.0f
										 alpha:1.0f];
	}
	if([aColour isEqualToString:@"purple"])
	{
		return [NSColor purpleColor];
	}
	if([aColour isEqualToString:@"red"])
	{
		return [NSColor redColor];
	}
	if([aColour isEqualToString:@"silver"])
	{
		return [NSColor lightGrayColor];
	}
	if([aColour isEqualToString:@"teal"])
	{
		return [NSColor colorWithCalibratedRed:0.0f
										 green:0.5f
										  blue:0.5f
										 alpha:1.0f];
	}
	if([aColour isEqualToString:@"white"])
	{
		return [NSColor whiteColor];
	}
	if([aColour isEqualToString:@"yellow"])
	{
		return [NSColor yellowColor];
	}
	return [NSColor blackColor];
}


@implementation ETXMLXHTML_IMParser

- (NSMutableDictionary *) attributes: (NSMutableDictionary *)attributes
                           fromStyle:  (NSString *)style
{
	NSFontManager * fontManager = [NSFontManager sharedFontManager];
	NSFont * font = [attributes objectForKey:NSFontAttributeName];
	if(font == nil)
	{
		font = [NSFont userFontOfSize:12.0f];
	}
	if(nil == attributes)
	{
		attributes = [NSMutableDictionary dictionary];
	}
	NSArray * styles = [style componentsSeparatedByString:@";"];
	//Parse each CSS property
	FOREACH(styles, theStyle, NSString*)
	{
		NSArray * styleComponents = [theStyle componentsSeparatedByString:@":"];
		if([styleComponents count] == 2)
		{
			NSString * k = TRIM([styleComponents objectAtIndex:0]);
			NSString * v = TRIM([styleComponents objectAtIndex:1]);
			if([k isEqualToString:@"color"])
			{
				[attributes setObject:colourFromCSSColourString(v)
							   forKey:NSForegroundColorAttributeName];
			}
			else if([k isEqualToString:@"background-color"] || [k isEqualToString:@"background"])
			{
				[attributes setObject:colourFromCSSColourString(v)
							   forKey:NSBackgroundColorAttributeName];
			}
			else if([k isEqualToString:@"font-family"])
			{
				NSFont * oldFont = font;
				NSArray * families = [v componentsSeparatedByString:@","];
				unsigned int numberOfFamilies = [families count];
				
				for(unsigned int i=0 ; i<numberOfFamilies ; i++)
				{
					//Try setting the new font family
					font = [fontManager convertFont:font
										   toFamily:TRIM([families objectAtIndex:i])];
					//If it worked, then use it
					if(font != oldFont)
					{
						break;
					}
				}
				
			}
			else if([k isEqualToString:@"font-size"])
			{
				NSNumber * size = [FONT_SIZES objectForKey:v];
				if(nil != size)
				{
					font = [fontManager convertFont:font toSize:[size floatValue]];
				}
				else
				{
					font = [fontManager convertFont:font toSize:[v floatValue]];
				}
			}
			else if([k isEqualToString:@"font-style"])
			{
				if([v isEqualToString:@"italic"] 
				   ||
				   [v isEqualToString:@"oblique"])
				{
					font = [fontManager convertFont:font toHaveTrait:NSItalicFontMask];
				}
				else if([v isEqualToString:@"normal"])
				{
					font = [fontManager convertFont:font toNotHaveTrait:NSItalicFontMask];
				}
			}
			else if([k isEqualToString:@"font-weight"])
			{
				//TODO: make this handle numeric weights
				if([v isEqualToString:@"bold"])
				{
					font = [fontManager convertFont:font toHaveTrait:NSBoldFontMask];
				}
				else if([v isEqualToString:@"normal"])
				{
					font = [fontManager convertFont:font toNotHaveTrait:NSBoldFontMask];
				}
			}
			else if([k isEqualToString:@"text-decoration"])
			{
				if([v isEqualToString:@"underline"])
				{
					[attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle]
								   forKey:NSUnderlineStyleAttributeName];
				}
				else if([v isEqualToString:@"line-through"])
				{
					[attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle]
								   forKey:NSStrikethroughStyleAttributeName];
				}
				else if([v isEqualToString:@"normal"])
				{
					[attributes setObject:nil
								   forKey:NSUnderlineStyleAttributeName];
					[attributes setObject:nil
								   forKey:NSStrikethroughStyleAttributeName];					
				}
			}
		}
	}
	[attributes setObject:font
				   forKey:NSFontAttributeName];
	return attributes;
}

- (void) loadStyles: (id)unused
{
//	stylesForTags = [[NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"XHTML-IM HTML Styles"]] retain];
	FONT_SIZES = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:6.0f],@"xx-small",
		[NSNumber numberWithFloat:8.0f],@"x-small",
		[NSNumber numberWithFloat:10.0f],@"small",
		[NSNumber numberWithFloat:12.0f],@"medium",
		[NSNumber numberWithFloat:14.0f],@"large",
		[NSNumber numberWithFloat:16.0f],@"x-large",
		[NSNumber numberWithFloat:18.0f],@"xx-large",
		nil] retain];
	//	if(nil == stylesForTags)
	{
		stylesForTags = [[NSMutableDictionary alloc] init];
		[stylesForTags setObject:@"font-style : italic"
						  forKey:@"em"];	
		[stylesForTags setObject:@"font-style : italic"
						  forKey:@"i"];	
		[stylesForTags setObject:@"color : blue ; text-decoration : underline"
						  forKey:@"a"];	
		[stylesForTags setObject:@"font-weight : bold"
						  forKey:@"b"];
		[stylesForTags setObject:@"font-weight : bold;font-size: xx-large"
						  forKey:@"h1"];	
		[stylesForTags setObject:@"font-weight : bold;font-size: x-large"
						  forKey:@"h2"];	
		[stylesForTags setObject:@"font-weight : bold;font-size: large"
						  forKey:@"h3"];
		[stylesForTags setObject:@"font-weight : bold"
						  forKey:@"h4"];
	}
}

- (id) initWithXMLParser: (id)aParser 
                  parent: (id <ETXMLParserDelegate>)aParent 
                     key: (id)aKey
{
	self = [super initWithXMLParser: aParser parent: aParent key: aKey];
	if (nil == self) { return nil; }

	string = [[NSMutableAttributedString alloc] init];
	currentAttributes = [[NSMutableDictionary alloc] init];	
	attributeStack = [[NSMutableArray alloc] init];

	lineBreakAfterTags = [[NSSet alloc] initWithObjects:
		@"p", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"h7", @"h8", @"h9",
		nil];
	lineBreakBeforeTags = [[NSSet alloc] initWithObjects:
		@"br", @"p", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"h7", @"h8", @"h9",
		nil];
	//Load stored tag to style mappings
	[self loadStyles:nil];

	//Request notification if these change
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(loadStyles:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
	return self;
}

- (void) characters: (NSString *)_chars
{
	NSMutableString * text = unescapeXMLCData(_chars);

	[text replaceOccurrencesOfString:@"\t"
						  withString:@" "
							 options:0
							   range:NSMakeRange(0, [text length])];
	[text replaceOccurrencesOfString:@"\n"
						  withString:@" "
							 options:0
							   range:NSMakeRange(0, [text length])];
	while([text replaceOccurrencesOfString:@"  "
						  withString:@" "
							 options:0
							   range:NSMakeRange(0, [text length])] > 0) {};
	NSString * existing  = [string string];
	int length = [existing length];
	if(((length > 0
	   &&
	   [existing characterAtIndex:length - 1] == ' ')
		||
		length == 0)
	   &&
	   [text length] > 0
	   &&
	   [text characterAtIndex:0] == ' ')
	{
		[text deleteCharactersInRange:NSMakeRange(0,1)];
	}

	if ([text length] > 0)
	{
		NSAttributedString * newSection = [[NSAttributedString alloc] initWithString:text
																	  attributes:currentAttributes];
		[string appendAttributedString:newSection];
		[newSection release];
	}
}

- (void) startElement: (NSString *)_Name
           attributes: (NSDictionary *)_attributes;
{
	_Name = [_Name lowercaseString];
	if([_Name isEqualToString:@"html"])
	{
		depth++;
	}
	if(depth == 0)
	{
		//Ignore any elements that are not <body>
		[[[ETXMLNullHandler alloc] initWithXMLParser:parser
											  parent:self
												 key:nil] startElement:_Name
															attributes:_attributes];
	}
	else
	{
		//Push the current style onto the stack
		[attributeStack addObject:currentAttributes];
		//Get the new attributes
		currentAttributes = [NSMutableDictionary dictionaryWithDictionary:currentAttributes];
		NSString *defaultTagStyle = [stylesForTags objectForKey: _Name];
		if (nil != defaultTagStyle)
		{
			currentAttributes = [self attributes: currentAttributes
			                           fromStyle: defaultTagStyle];
		}
		NSString *style = attributeForCaseInsensitiveKey(_attributes, @"style");
		//Special case for hyperlinks
		if([_Name isEqualToString:@"a"])
		{
			//Set the link target
			id v = attributeForCaseInsensitiveKey(_attributes, @"href");
			if (v)
				[currentAttributes setObject:v
									  forKey:NSLinkAttributeName];
		}
		//Display alt tags for images
		//TODO:  Make it optional to get the real image
		else if([_Name isEqualToString:@"img"])
		{
			NSString * alt = attributeForCaseInsensitiveKey(_attributes, @"alt");
			if(alt != nil)
			{
				[self characters:alt];
			}
		}
		//Get an explicit style
		if(style != nil)
		{
			currentAttributes = [self attributes: currentAttributes fromStyle: style];
		}
		[currentAttributes retain];
		//And some line breaks...
		if([lineBreakBeforeTags containsObject:_Name])
		{
			if([string length] > 0 || [_Name isEqualToString:@"br"])
			{
				NSAttributedString * newline = [[NSAttributedString alloc] initWithString:@"\n"];
				[string appendAttributedString:newline];
				[newline release];
			}
		}
		//Increment the depth counter.  This should always be equal to [attributeStack count] + 1, and it might be worth using this for validation
	}
}

- (void) endElement: (NSString *)_Name
{
	_Name = [_Name lowercaseString];
	if([_Name isEqualToString:@"html"])
	{
		depth--;
	}
	if(depth == 0)
	{
		[parser setContentHandler: parent];
		[self notifyParent];
		[self release];
	}
	else
	{
		if([lineBreakAfterTags containsObject:_Name])
		{
			NSAttributedString * newline = [[NSAttributedString alloc] initWithString:@"\n"];
			[string appendAttributedString:newline];
			[newline release];
		}
		[currentAttributes release];
		currentAttributes = [attributeStack lastObject];
		[attributeStack removeLastObject];
	}
}

- (void) notifyParent
{
	[(id)parent addChild:string forKey:key];
}

- (void) dealloc
{
	[currentAttributes release];
	[attributeStack release];
	[string release];
	[FONT_SIZES release];
	[stylesForTags release];
	[lineBreakAfterTags release];
	[lineBreakBeforeTags release];
	[super dealloc];
}

@end
