#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreUndeleteBranch : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;

@end
