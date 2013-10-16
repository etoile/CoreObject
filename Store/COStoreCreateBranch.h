#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreCreateBranch : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) ETUUID *parentBranch;
@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;
@property (nonatomic, retain, readwrite) ETUUID *initialRevision;

@end
