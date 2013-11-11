#import <CoreObject/COSynchronizerServer.h>

@protocol COSynchronizerJSONServerDelegate <NSObject>

- (void) sendText: (NSString *)text toClient: (NSString *)client;

@end

@interface COSynchronizerJSONServer : NSObject <COSynchronizerServerDelegate>

@property (nonatomic, readwrite, strong) id<COSynchronizerJSONServerDelegate> delegate;
@property (nonatomic, readwrite, weak) COSynchronizerServer *server;

- (void) receiveText: (NSString *)text fromClient: (NSString *)aClient;

@end
