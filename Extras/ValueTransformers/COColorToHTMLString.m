/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "COColorToHTMLString.h"

@implementation COColorToHTMLString

+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

static NSString *HexFromFraction(CGFloat fraction)
{
	return [NSString stringWithFormat: @"%02x", (unsigned char)(fraction * 255)];
}

static CGFloat FractionFromHex(NSString *twoChars)
{
	int value = 0;
	if (1 == sscanf([twoChars UTF8String], "%x", &value))
	{
		return value / 255.0;
	}
	return 0;
}

static NSString *ColorToString(NSColor *color)
{
	NSColor *rgbColor = color;
	CGFloat a, r, g, b;

	// NOTE: iOS does not support device-independent or generic color spaces
#if !(TARGET_OS_IPHONE)
	rgbColor = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
#endif
	[rgbColor getRed: &r green: &g blue: &b alpha: &a];
	
	return [NSString stringWithFormat: @"#%@%@%@%@",
		HexFromFraction(a), HexFromFraction(r), HexFromFraction(g), HexFromFraction(b)];
}

static NSColor *ColorFromString(NSString *color)
{
	CGFloat a = FractionFromHex([color substringWithRange: NSMakeRange(1, 2)]);
	CGFloat r = FractionFromHex([color substringWithRange: NSMakeRange(3, 2)]);
	CGFloat g = FractionFromHex([color substringWithRange: NSMakeRange(5, 2)]);
	CGFloat b = FractionFromHex([color substringWithRange: NSMakeRange(7, 2)]);

#if TARGET_OS_IPHONE
	return [UIColor colorWithRed: r green: g blue: b alpha: a];
#else
	return [NSColor colorWithCalibratedRed: r green: g blue: b alpha: a];
#endif
}

- (id)transformedValue: (id)value
{
    if (value == nil)
        return  nil;

	ETAssert([value isKindOfClass: [NSColor class]]);
	NSColor *color = value;
	
	NSString *string = ColorToString(color);
	return string;
}

- (id)reverseTransformedValue: (id)value
{
    if (value == nil)
        return nil;

	ETAssert([value isKindOfClass: [NSString class]]);
	NSString *string = value;
	
	NSColor *color = ColorFromString(string);
	return color;
}

@end
