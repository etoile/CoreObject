/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  February 2014
    License:  MIT  (see COPYING)
 */

#import "EWTextView.h"
#import <CoreObject/COSQLiteStore+Attachments.h>

@implementation EWTextView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
    }    
    return self;
}

// TODO: copy -readSelectionFromPasteboard: from ProjectDemo if we want to support attachment import via drag & drop

@end
