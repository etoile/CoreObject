/*
	Copyright (C) 2013 Eric Wasylishen

	Author:  Eric Wasylishen <ewasylishen@gmail.com>
	Date:  November 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COSQLiteStore.h>

@class ETUUID;

@interface COSQLiteStore (Debugging)

- (NSString *) dotGraphForPersistentRootUUID: (ETUUID *)aUUID;

- (void) showGraphForPersistentRootUUID: (ETUUID *)aUUID;

@end
