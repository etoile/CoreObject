#import <CoreObject/CoreObject.h>

/**
 * This is a fake for the message transport mechanism between client and server,
 * that buffers messages in arrays, and executes them when requested.
 *
 * ProjectDemo will provide an implementation of a real one over XMPP.
 */
@interface FakeMessageTransport : NSObject <COSynchronizerClientDelegate, COSynchronizerServerDelegate>
{
	COSynchronizerServer *server;
	NSMutableArray *serverMessages;
	
	NSMutableDictionary *clientForID;
	NSMutableDictionary *clientMessagesForID;
}

- (id) initWithSynchronizerServer: (COSynchronizerServer *)aServer;
- (void) addClient: (COSynchronizerClient *)aClient;

@property (nonatomic, readonly, strong) COSynchronizerServer *server;

- (void) deliverMessages;
- (BOOL) deliverMessagesToClient;
- (BOOL) deliverMessagesToClient: (NSString *)clientID;
- (BOOL) deliverMessagesToServer;

- (NSArray *) serverMessages;
- (NSArray *) messagesForClient: (NSString *)anID;

@end