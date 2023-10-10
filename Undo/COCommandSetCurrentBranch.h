/**
    Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

    Date:  September 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

NS_ASSUME_NONNULL_BEGIN

@interface COCommandSetCurrentBranch : COCommand
{
    ETUUID *_oldBranchUUID;
    ETUUID *_newBranchUUID;
}

@property (nonatomic, readwrite, copy) ETUUID *oldBranchUUID;
@property (nonatomic, readwrite, copy) ETUUID *branchUUID;

@end

NS_ASSUME_NONNULL_END
