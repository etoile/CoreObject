/**
    Copyright (C) 2013 Eric Wasylishen

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface COStoreSetCurrentRevision : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) ETUUID *currentRevision;
@property (nonatomic, retain, readwrite, nullable) ETUUID *headRevision;

@end

NS_ASSUME_NONNULL_END
