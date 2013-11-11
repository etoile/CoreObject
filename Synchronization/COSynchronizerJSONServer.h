#import <CoreObject/COSynchronizerServer.h>

@class COSynchronizerJSONServer;

@protocol COSynchronizerJSONServerDelegate <NSObject>

- (void) JSONServer: (COSynchronizerJSONServer *)server sendText: (NSString *)text toClient: (NSString *)client;

@end

@interface COSynchronizerJSONServer : NSObject <COSynchronizerServerDelegate>

@property (nonatomic, readwrite, strong) id<COSynchronizerJSONServerDelegate> delegate;
@property (nonatomic, readwrite, weak) COSynchronizerServer *server;

- (void) receiveText: (NSString *)text fromClient: (NSString *)aClient;

@end
