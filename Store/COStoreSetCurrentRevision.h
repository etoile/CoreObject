/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreSetCurrentRevision : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) ETUUID *currentRevision;
@property (nonatomic, retain, readwrite) ETUUID *headRevision;

@end
