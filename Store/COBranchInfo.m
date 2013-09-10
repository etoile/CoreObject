#import "COBranchInfo.h"
#import "CORevisionID.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation COBranchInfo

@synthesize UUID = uuid_;
@synthesize tailRevisionID = tailRevisionId_;
@synthesize currentRevisionID = currentRevisionId_;
@synthesize deleted = deleted_;
@synthesize metadata = metadata_;

- (void) dealloc
{
    [uuid_ release];
    [tailRevisionId_ release];
    [currentRevisionId_ release];
    [metadata_ release];
    [super dealloc];
}

- (ETUUID *) remoteMirror
{
    NSString *value = metadata_[@"remoteMirror"];
    if (value != nil)
    {
        return [ETUUID UUIDWithString: value];
    }
    return nil;
}

- (ETUUID *) replcatedBranch
{
    NSString *value = metadata_[@"replcatedBranch"];
    if (value != nil)
    {
        return [ETUUID UUIDWithString: value];
    }
    return nil;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<Branch %@ <curr. rev.: %@> %@>", uuid_, currentRevisionId_, metadata_];
}

@end