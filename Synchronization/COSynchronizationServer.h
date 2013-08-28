#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import <EtoileFoundation/EtoileFoundation.h>

@interface COSynchronizationServer : NSObject

- (NSDictionary *) handleUpdateRequest: (NSDictionary *)aRequest
                                 store: (COSQLiteStore *)aStore;

@end
