#import <CoreObject/CoreObject.h>
#import "CoreObject/COStoreAction.h"

/**
 * Creates an empty persistent root (with no branches).
 * If persistentRootForCopy is set, shares a backing store with that persistent
 * root, otherwise, creates a new backing store.
 */
@interface COStoreCreatePersistentRoot : NSObject <COStoreAction>

@property (nonatomic, retain, readwrite) ETUUID *persistentRoot;
@property (nonatomic, retain, readwrite) ETUUID *persistentRootForCopy;

@end
