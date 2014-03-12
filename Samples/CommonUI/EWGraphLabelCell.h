/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  February 2014
	License:  MIT  (see COPYING)
 */

 #import <Cocoa/Cocoa.h>

#import "EWGraphRenderer.h"

@interface EWGraphLabelCell : NSCell
{
	IBOutlet EWGraphRenderer *graphRenderer;
}

@end
