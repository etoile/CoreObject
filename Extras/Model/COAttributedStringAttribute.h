/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  December 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COAttributedStringAttribute : COObject

@property (nonatomic, readwrite, strong) NSString *htmlCode;

/**
 * Overridden. Compares htmlCode.
 */
- (BOOL) isEqual: (id)anObject;

- (COItemGraph *) attributeItemGraph;

@end
