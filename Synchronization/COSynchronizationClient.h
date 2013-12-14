/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

@interface COSynchronizationClient : NSObject

- (NSDictionary *) updateRequestForPersistentRoot: (ETUUID *)aRoot
                                         serverID: (NSString*)anID
                                            store: (COSQLiteStore *)aStore;

- (void) handleUpdateResponse: (NSDictionary *)aResponse
                        store: (COSQLiteStore *)aStore;
@end
