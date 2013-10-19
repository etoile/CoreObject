#import <Foundation/Foundation.h>

@class ETUUID;
@class CORevisionID;

@interface COSearchResult : NSObject
{
    CORevisionID *revision_;
    ETUUID *innerObjectUUID_;
}

@property (nonatomic, readwrite, strong) CORevisionID *revision;
@property (nonatomic, readwrite, strong) ETUUID *innerObjectUUID;

@end
