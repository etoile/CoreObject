/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreWriteRevision : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) COItemGraph *modifiedItems;
@property (nonatomic, retain, readwrite) ETUUID *revisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *parentRevisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *mergeParentRevisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) NSDictionary *metadata;

@end
