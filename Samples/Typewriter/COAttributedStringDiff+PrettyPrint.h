/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  April 2014
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COAttributedStringDiff.h>

@interface COAttributedStringDiff (PrettyPrint)

- (NSAttributedString *)prettyPrintedWithSource: (NSAttributedString *)string;

@end
