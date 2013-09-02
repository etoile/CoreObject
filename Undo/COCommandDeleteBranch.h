#import <CoreObject/COCommand.h>

@interface COCommandDeleteBranch : COSingleCommand
{
    ETUUID *_branchUUID;
}

@property (readwrite, nonatomic, copy) ETUUID *branchUUID;

@end
