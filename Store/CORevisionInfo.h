#import <Foundation/Foundation.h>

@class CORevisionID;

/**
 *  Info about a commit. Parent revision (maybe nil), metadata, etc.
 *  There's a 1:1 mapping between a CORevisionID and CORevision per store.
 */
@interface CORevisionInfo : NSObject
{
    @private
    CORevisionID *_revisionID;
    CORevisionID *_parentRevisionID;
    CORevisionID *_mergeParentRevisionID;
    NSDictionary *_metadata;
    NSDate *_date;
}

@property (readwrite, nonatomic, retain) CORevisionID *revisionID;
@property (readwrite, nonatomic, retain) CORevisionID *parentRevisionID;
@property (readwrite, nonatomic, retain) CORevisionID *mergeParentRevisionID;
@property (readwrite, nonatomic, copy) NSDictionary *metadata;
@property (readwrite, nonatomic, retain) NSDate *date;

- (id) plist;
+ (CORevisionInfo *) revisionInfoWithPlist: (id)aPlist;

@end
