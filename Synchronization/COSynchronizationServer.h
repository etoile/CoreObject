/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  August 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

@interface COSynchronizationServer : NSObject

- (NSDictionary *) handleUpdateRequest: (NSDictionary *)aRequest
                                 store: (COSQLiteStore *)aStore;

@end
