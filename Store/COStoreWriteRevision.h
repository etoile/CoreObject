#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreWriteRevision : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) COItemGraph *modifiedItems;
@property (nonatomic, retain, readwrite) ETUUID *revisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *parentRevisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *mergeParentRevisionUUID;
@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;
@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) NSDictionary *metadata;

@end
