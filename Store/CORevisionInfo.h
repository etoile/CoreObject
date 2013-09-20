#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETUUID.h>

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
    ETUUID *_persistentRootUUID;
	ETUUID *_branchUUID;
    NSDictionary *_metadata;
    NSDate *_date;
}

@property (readwrite, nonatomic, strong) CORevisionID *revisionID;
@property (readwrite, nonatomic, strong) CORevisionID *parentRevisionID;
@property (readwrite, nonatomic, strong) CORevisionID *mergeParentRevisionID;
@property (readwrite, nonatomic, strong) ETUUID *persistentRootUUID;
@property (readwrite, nonatomic, strong) ETUUID *branchUUID;
@property (readwrite, nonatomic, copy) NSDictionary *metadata;
@property (readwrite, nonatomic, strong) NSDate *date;

- (id) plist;
+ (CORevisionInfo *) revisionInfoWithPlist: (id)aPlist;

@end
