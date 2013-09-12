#import <Foundation/Foundation.h>

@class ETUUID;
@class CORevisionID;

@interface COSearchResult : NSObject
{
    CORevisionID *revision_;
    ETUUID *embeddedObjectUUID_;
}

@property (nonatomic, readwrite, strong) CORevisionID *revision;
@property (nonatomic, readwrite, strong) ETUUID *embeddedObjectUUID;

@end
