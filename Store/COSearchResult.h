#import <Foundation/Foundation.h>

@class CORevisionID, ETUUID;

@interface COSearchResult : NSObject
{
    CORevisionID *revision_;
    ETUUID *embeddedObjectUUID_;
}

@property (nonatomic, readwrite, retain) CORevisionID *revision;
@property (nonatomic, readwrite, retain) ETUUID *embeddedObjectUUID;

@end
