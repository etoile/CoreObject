#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreSetCurrentBranch : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;

@end
