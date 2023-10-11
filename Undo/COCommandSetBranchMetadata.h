/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

NS_ASSUME_NONNULL_BEGIN

@interface COCommandSetBranchMetadata : COCommand
{
    ETUUID *_branchUUID;
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (nonatomic, readwrite, copy) ETUUID *branchUUID;
@property (nonatomic, readwrite, copy, nullable) NSDictionary<NSString *, id> *oldMetadata;
@property (nonatomic, readwrite, copy, nullable) NSDictionary<NSString *, id> *metadata;

@end

NS_ASSUME_NONNULL_END

