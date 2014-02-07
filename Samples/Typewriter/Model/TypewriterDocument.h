/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */


#import <CoreObject/CoreObject.h>
#import <CoreObject/COAttributedString.h>

@interface TypewriterDocument : COObject
@property (nonatomic, readwrite, retain) COAttributedString *attrString;
@end
