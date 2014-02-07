/**
	Copyright (C) 2013 Eric Wasylishen, Quentin Mathe

	Date:  September 2013
	License:  MIT  (see COPYING)
 */

#import <CoreObject/COCommand.h>

@interface COCommandSetBranchMetadata : COSingleCommand
{
    ETUUID *_branchUUID;
    NSDictionary *_oldMetadata;
    NSDictionary *_newMetadata;
}

@property (nonatomic, copy) ETUUID *branchUUID;
@property (nonatomic, copy) NSDictionary *oldMetadata;
@property (nonatomic, copy) NSDictionary *metadata;

@end
