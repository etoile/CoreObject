#import <CoreObject/COCommand.h>

@interface COCommandUndeleteBranch : COSingleCommand
{
    ETUUID *_branchUUID;
}

@property (nonatomic, copy) ETUUID *branchUUID;

@end
