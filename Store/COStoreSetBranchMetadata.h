#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

@interface COStoreSetBranchMetadata : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *branch;
@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;
@property (nonatomic, retain, readwrite) NSDictionary *metadata;


@end
