/*
	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  September 2007
	License: Modified BSD (see COPYING)
 */

#import "NSString+Etoile.h"

#ifdef GNUSTEP
@interface GSString : NSString
+ (void)reinitialize;
@end
#endif

@implementation NSString (Etoile)

#ifdef GNUSTEP
+ (void)load
{
	if ([GSString respondsToSelector: @selector(reinitialize)])
	{
		[GSString reinitialize];
	}
}
#endif

/** Returns the first path component of the receiver. If the receiver isn't a 
path, returns the a new instance of the entire string. 

If the path is '/', returns '/'.<br />
If the path is '/where/who' or 'where/who', returns 'where'. */
- (NSString *) firstPathComponent
{
	NSArray *pathComponents = [self pathComponents];
	NSString *firstPathComp = nil;
	
	if ([pathComponents count] > 0)
		firstPathComp = [pathComponents objectAtIndex: 0];

	return firstPathComp;
}

/** Returns a new string instance by stripping the first path component as 
defined by -firstPathComponent. */
- (NSString *) stringByDeletingFirstPathComponent
{
	NSArray *pathComponents = [self pathComponents];
	
	pathComponents = [pathComponents subarrayWithRange: NSMakeRange(1, [pathComponents count] - 1)];
	
	return [NSString pathWithComponents: pathComponents];
}

/** Returns a string where all words are separated by spaces for a given string 
of capitalized words with no spaces at all. 

Useful to convert a name in camel case into a more user friendly name. */
- (NSString *) stringBySpacingCapitalizedWords
{
	NSScanner *scanner = [NSScanner scannerWithString: self];
	NSCharacterSet *charset = [NSCharacterSet uppercaseLetterCharacterSet];
	NSString *word = nil;
	NSMutableString *displayName = [NSMutableString stringWithCapacity: 40];
	BOOL beforeLastLetter = NO;

	do
	{
		/* Scan a first capital or an uppercase word */
		BOOL hasScannedCapitals = [scanner scanCharactersFromSet: charset
	                                                  intoString: &word];
		if (hasScannedCapitals)
		{
			beforeLastLetter = ([scanner isAtEnd] == NO);
			BOOL hasFoundUppercaseWord = ([word length] > 1);
			if (hasFoundUppercaseWord && beforeLastLetter)
			{
				[displayName appendString: [word substringToIndex: [word length] - 1]];
				[displayName appendString: @" "]; /* Add a space between each words */
				[displayName appendString: [word substringFromIndex: [word length] - 1]];
			}
			else /* single capital or uppercase word at the end */
			{
				[displayName appendString: word];
			}
		}

		/* Scan lowercase characters, either a full word or what follows the 
		   a capital until the next one */
		BOOL hasFoundNextCapitalOrEnd = [scanner scanUpToCharactersFromSet: charset
	                                                            intoString: &word];
		if (hasFoundNextCapitalOrEnd)
		{
			[displayName appendString: word];

			/* Add a space between each words */
			beforeLastLetter = ([scanner isAtEnd] == NO);
			BOOL beyondFirstCapital = ([scanner scanLocation] > 0);
			if (beyondFirstCapital && beforeLastLetter)
			{
				[displayName appendString: @" "];
			}
		}
	} while (beforeLastLetter);

	return displayName;
}

// FIXME: Implement
- (NSIndexPath *) indexPathBySplittingPathWithSeparator: (NSString *)separator
{
	return nil;
}

- (BOOL)isEqualToString: (NSString*)aString
{
	NSUInteger length = [self length];
	if ([aString length] != length) { return NO; }

	NSRange range = { 0, 30 };
	while (range.location < length)
	{
		unichar buffer[30];
		unichar buffer2[30];
		if (range.location + range.length > length)
		{
			range.length = length - range.location;
		}
		[aString getCharacters: buffer range: range];
		[self getCharacters: buffer2 range: range];
		range.location += 30;
		for (unsigned i=0 ; i<range.length ; i++)
		{
			if (buffer[i] != buffer2[i]) { return NO; }
		}
	}

	return YES;
}

@end

