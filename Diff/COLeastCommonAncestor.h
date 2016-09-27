/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/COEditingContext.h>

@class ETUUID;

@interface COEditingContext (CommonAncestor)

- (ETUUID *)commonAncestorForCommit: (ETUUID *)commitA
                          andCommit: (ETUUID *)commitB
                     persistentRoot: (ETUUID *)persistentRoot;

- (BOOL)       isRevision: (ETUUID *)commitA
equalToOrParentOfRevision: (ETUUID *)commitB
           persistentRoot: (ETUUID *)persistentRoot;

/**
 * As a sepecial case if [start isEqual: end] returns the empty array
 */
- (NSArray *)revisionUUIDsFromRevisionUUIDExclusive: (ETUUID *)start
                            toRevisionUUIDInclusive: (ETUUID *)end
                                     persistentRoot: (ETUUID *)persistentRoot;

@end
