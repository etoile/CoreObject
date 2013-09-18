#import <CoreObject/CoreObject.h>
#import "CORevisionCache.h"
#import "CORevision.h"

@implementation CORevisionCache

- (instancetype) initWithEditingContext: (COEditingContext *)aContext
{
    SUPERINIT;
    _owner = aContext;
    _revisionForRevisionID = [[NSMutableDictionary alloc] init];
    return self;
}

- (CORevision *) revisionForRevisionID: (CORevisionID *)aRevid
{
    CORevision *cached = [_revisionForRevisionID objectForKey: aRevid];
    if (cached == nil)
    {
        CORevisionInfo *info = [[_owner store] revisionInfoForRevisionID: aRevid];
        
        cached = [[CORevision alloc] initWithEditingContext: _owner
                                               revisionInfo: info];
        
        [_revisionForRevisionID setObject: cached forKey: aRevid];
    }
    return cached;
}

@end
