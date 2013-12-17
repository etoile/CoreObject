/*
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandSetCurrentBranch : COSingleCommand
{
    ETUUID *_oldBranchUUID;
    ETUUID *_newBranchUUID;
}

@property (nonatomic, copy) ETUUID *oldBranchUUID;
@property (nonatomic, copy) ETUUID *branchUUID;

@end
