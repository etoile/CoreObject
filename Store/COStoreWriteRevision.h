/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface COStoreWriteRevision : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) COItemGraph *modifiedItems;
@property (nonatomic, retain, readwrite) ETUUID *revisionUUID;
@property (nonatomic, retain, readwrite, nullable) ETUUID *parentRevisionUUID;
@property (nonatomic, retain, readwrite, nullable) ETUUID *mergeParentRevisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, assign, readwrite) int64_t schemaVersion;
@property (nonatomic, retain, readwrite, nullable) NSDictionary<NSString *, id> *metadata;

@end

NS_ASSUME_NONNULL_END
