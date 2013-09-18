#import <Foundation/Foundation.h>

@class CORevision;
@class CORevisionID;
@class COEditingContext;

@interface CORevisionCache : NSObject
{
    COEditingContext * __weak _owner;
    NSMutableDictionary *_revisionForRevisionID;
}

- (instancetype) initWithEditingContext: (COEditingContext *)aContext;

- (CORevision *) revisionForRevisionID: (CORevisionID *)aRevid;

@end
