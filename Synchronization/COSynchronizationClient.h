/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

/**
 * This class and COSynchronizationServer were a rough sketch of how we could
 * replicate persistent roots between stores, and fetch updates after an
 * initial replication. It doesn't handle merging changes so it's not very
 * useful.
 *
 * It remains here because it would be a good thing to have finished at some point,
 * and the tests exercised some store functionality that wasn't well tested elsewhere.
 */
@interface COSynchronizationClient : NSObject

- (NSDictionary *)updateRequestForPersistentRoot: (ETUUID *)aRoot
                                        serverID: (NSString *)anID
                                           store: (COSQLiteStore *)aStore;

- (void)handleUpdateResponse: (NSDictionary *)aResponse
                       store: (COSQLiteStore *)aStore;

@end
