/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  April 2014
    License:  MIT  (see COPYING)
 */

#import "COPersistentRoot+Revert.h"

@implementation COPersistentRoot (Revert)

- (CORevision*) revisionToRevertTo
{
    CORevision *inspectedRevision = [self currentRevision];
    while (inspectedRevision != nil
           && ![inspectedRevision.commitDescriptor.identifier isEqualToString: @"org.etoile.CoreObject.checkpoint"])
    {
        inspectedRevision = [inspectedRevision parentRevision];
    }
    return inspectedRevision;
}

@end
