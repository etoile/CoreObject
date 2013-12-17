/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreSetPersistentRootMetadata : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) NSDictionary *metadata;

@end
