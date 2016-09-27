/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  April 2014
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>

@interface COPersistentRoot (Revert)

- (CORevision*) revisionToRevertTo;

@end
