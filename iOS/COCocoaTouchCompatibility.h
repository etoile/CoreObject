/*
	Copyright (C) 2014 Quentin Mathe

	Date:  July 2014
	License:  MIT  (see COPYING)
 */

#if TARGET_OS_IPHONE

#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

#define NSApplication UIApplication

/* Font and CoreText */

#define NSFont UIFont
#define NSFontDescriptor UIFontDescriptor
#define NSFontSymbolicTraits UIFontDescriptorSymbolicTraits
#define NSFontBoldTrait UIFontDescriptorTraitBold
#define NSFontItalicTrait UIFontDescriptorTraitItalic
#define NSForegroundColorAttributeName (NSString *)kCTForegroundColorAttributeName

/* Color */

#define NSColor UIColor

/* Views */

#define NSTextView UITextView

#endif
