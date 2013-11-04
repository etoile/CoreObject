#import <CoreObject/COSQLiteStore.h>

@class ETUUID;

@interface COSQLiteStore (Debugging)

- (NSString *) dotGraphForPersistentRootUUID: (ETUUID *)aUUID;

- (void) showGraphForPersistentRootUUID: (ETUUID *)aUUID;

@end
