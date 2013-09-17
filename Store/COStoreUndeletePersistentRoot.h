#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreUndeletePersistentRoot : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;

@end
