#import "COBranchInfo.h"
#import "CORevisionID.h"

@implementation COBranchInfo

@synthesize UUID = uuid_;
@synthesize headRevisionID = headRevisionId_;
@synthesize tailRevisionID = tailRevisionId_;
@synthesize currentRevisionID = currentRevisionId_;
@synthesize deleted = deleted_;
@synthesize metadata = metadata_;

- (void) dealloc
{
    [uuid_ release];
    [headRevisionId_ release];
    [tailRevisionId_ release];
    [currentRevisionId_ release];
    [metadata_ release];
    [super dealloc];
}

@end