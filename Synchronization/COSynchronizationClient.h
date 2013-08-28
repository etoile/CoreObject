#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

@interface COSynchronizationClient : NSObject

- (NSDictionary *) updateRequestForPersistentRoot: (ETUUID *)aRoot
                                            store: (COSQLiteStore *)aStore;

- (void) handleUpdateResponse: (NSDictionary *)aResponse
                        store: (COSQLiteStore *)aStore;
@end
