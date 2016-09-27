/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COSQLiteStore.h>

@class ETUUID;

void COViewDOTGraphFile(NSString *path);

@interface COSQLiteStore (Debugging)

- (NSString *)dotGraphForPersistentRootUUID: (ETUUID *)aUUID;
- (void)showGraphForPersistentRootUUID: (ETUUID *)aUUID;

@end
