#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreDeletePersistentRoot : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;

@end
