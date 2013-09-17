#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreSetCurrentRevision : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;
@property (nonatomic, retain, readwrite) ETUUID *currentRevision;

@end
