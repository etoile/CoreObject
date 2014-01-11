/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

@class COAttributedString;

@interface COAttributedStringWrapper : NSTextStorage
{
	COAttributedString *_backing;
	NSUInteger _lastNotifiedLength;
	BOOL _inPrimitiveMethod;
	NSString *_cachedString;
}

- (instancetype) initWithBacking: (COAttributedString *)aBacking;

@property (nonatomic, readonly, strong) COAttributedString *backing;

@end
