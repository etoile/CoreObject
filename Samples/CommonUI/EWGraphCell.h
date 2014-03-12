/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  January 2014
	License:  MIT  (see COPYING)
 */

#import <Cocoa/Cocoa.h>

#import "EWGraphRenderer.h"

@interface EWGraphCell : NSCell
{
	IBOutlet EWGraphRenderer *graphRenderer;
}

@end
