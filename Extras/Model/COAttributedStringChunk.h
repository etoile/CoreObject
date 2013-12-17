/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COAttributedStringChunk : COObject
@property (nonatomic, readwrite, strong) NSString *text;
@property (nonatomic, readwrite, strong) NSString *htmlCode;
@end
