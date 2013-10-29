#import <CoreObject/COCommand.h>

@interface COCommandDeleteBranch : COSingleCommand
{
    ETUUID *_branchUUID;
}

@property (nonatomic, copy) ETUUID *branchUUID;

@end
