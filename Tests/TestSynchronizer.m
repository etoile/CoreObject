#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

#define CLIENT_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore2.sqlite" stringByExpandingTildeInPath]]

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

- (COSynchronizerClient *) addClientWithID: (NSString *)anID editingContext: (COEditingContext *)aContext;

@property (nonatomic, readonly, strong) COSynchronizerServer *server;

- (void) deliverMessages;

@end

@implementation FakeMessageTransport

@synthesize server = server;

- (id) initWithSynchronizerServer: (COSynchronizerServer *)aServer
{
	SUPERINIT;
	server = aServer;
	server.delegate = self;
	serverMessages = [NSMutableArray new];
	clientForID = [NSMutableDictionary new];
	clientMessagesForID = [NSMutableDictionary new];
	return self;
}

- (void) sendReceiptToServer: (COSynchronizerAcknowledgementFromClientMessage *)message
{
	[serverMessages addObject: message];
}
- (void) sendPushToServer: (COSynchronizerPushedRevisionsFromClientMessage *)message
{
	[serverMessages addObject: message];
}
- (void) sendResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aMessage
					toClient: (NSString *)aClient
{
	[self queueMessage: aMessage forClient: aClient];
}
- (void) sendPushedRevisions: (COSynchronizerPushedRevisionsToClientMessage *)aMessage
				   toClients: (NSArray *)clients
{
	for (NSString *client in clients)
	{
		[self queueMessage: aMessage forClient: client];
	}
}
- (void) sendPersistentRootInfoMessage: (COSynchronizerPersistentRootInfoToClientMessage *)aMessage
							  toClient: (NSString *)aClient
{
	[self queueMessage: aMessage forClient: aClient];
}

- (void) queueMessage: (id)aMessage forClient: (NSString *)aClient
{
	NSMutableArray *array = [clientMessagesForID objectForKey: aClient];
	if (array == nil)
	{
		array = [[NSMutableArray alloc] init];
		[clientMessagesForID setObject: array forKey: aClient];
	}
	[array addObject: aMessage];
}

- (BOOL) deliverMessagesToServer
{
	BOOL deliveredAny = NO;
	
	NSArray *messages = [serverMessages copy];
	[serverMessages removeAllObjects];
	
	for (id message in messages)
	{
		deliveredAny = YES;
		if ([message isKindOfClass: [COSynchronizerAcknowledgementFromClientMessage class]])
		{
			[server handleReceiptFromClient: message];
		}
		else if ([message isKindOfClass: [COSynchronizerPushedRevisionsFromClientMessage class]])
		{
			[server handlePushedRevisionsFromClient: message];
		}
		else
		{
			NSAssert(NO, @"Unsupported server message class: %@", [message class]);
		}
	}
	return deliveredAny;
}

- (BOOL) deliverMessagesToClient
{
	BOOL deliveredAny = NO;
	
	for (NSString *clientID in clientMessagesForID)
	{
		NSArray *messages = [clientMessagesForID[clientID] copy];
		COSynchronizerClient *client = clientForID[clientID];
		ETAssert(client != nil);
		
		[clientMessagesForID[clientID] removeAllObjects];
		
		for (id message in messages)
		{
			deliveredAny = YES;
			if ([message isKindOfClass: [COSynchronizerPushedRevisionsToClientMessage class]])
			{
				[client handlePushMessage: message];
			}
			else if ([message isKindOfClass: [COSynchronizerResponseToClientForSentRevisionsMessage class]])
			{
				[client handleResponseMessage: message];
			}
			else
			{
				NSAssert(NO, @"Unsupported server message class: %@", [message class]);
			}
		}
	}
	return deliveredAny;
}

- (void) deliverMessages
{
	BOOL deliveredAny = NO;
	do
	{
		deliveredAny = deliveredAny || [self deliverMessagesToClient];
		deliveredAny = deliveredAny || [self deliverMessagesToServer];
	}
	while (deliveredAny == YES);
}

- (COSynchronizerClient *) addClientWithID: (NSString *)anID editingContext: (COEditingContext *)aContext
{
	[server addClientID: anID];
	
	ETAssert([clientMessagesForID[anID] count] == 1);
	ETAssert([clientMessagesForID[anID][0] isKindOfClass: [COSynchronizerPersistentRootInfoToClientMessage class]]);
	COSynchronizerPersistentRootInfoToClientMessage *setupMessage = clientMessagesForID[anID][0];
	[clientMessagesForID[anID] removeAllObjects];
	
	COSynchronizerClient *client = [[COSynchronizerClient alloc] initWithSetupMessage: setupMessage
																			 clientID: anID
																	   editingContext: aContext];
	client.delegate = self;
	clientForID[anID] = client;
	return client;
}

@end




@interface TestSynchronizer : EditingContextTestCase <UKTest>
{
	COSynchronizerServer *server;
	COPersistentRoot *serverPersistentRoot;
	COBranch *serverBranch;
	
	FakeMessageTransport *transport;
	
	COSynchronizerClient *client;
	COEditingContext *clientCtx;
	COPersistentRoot *clientPersistentRoot;
	COBranch *clientBranch;
}
@end

@implementation TestSynchronizer

- (id) init
{
	SUPERINIT;
	
	[[[COSQLiteStore alloc] initWithURL: CLIENT_STORE_URL] clearStore];
	
	serverPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	serverBranch = [serverPersistentRoot currentBranch];
	[ctx commit];
	
	server = [[COSynchronizerServer alloc] initWithBranch: serverBranch];
	transport = [[FakeMessageTransport alloc] initWithSynchronizerServer: server];

	clientCtx = [COEditingContext contextWithURL: CLIENT_STORE_URL];
	client = [transport addClientWithID: @"client" editingContext: clientCtx];
	clientPersistentRoot = client.persistentRoot;
	clientBranch = client.branch;
	
	return self;
}

- (void) testBasicReplicationToClient
{
	UKNotNil(clientPersistentRoot);
	UKNotNil(clientBranch);
	UKNotNil(clientPersistentRoot.currentBranch);
	UKObjectsSame(clientBranch, clientPersistentRoot.currentBranch);
	UKObjectsEqual([serverPersistentRoot UUID], [clientPersistentRoot UUID]);
	UKObjectsEqual([serverBranch UUID], [clientBranch UUID]);
	UKObjectsEqual([[serverBranch rootObject] UUID], [[clientBranch rootObject] UUID]);
}

- (COObject *) addAndCommitServerChild
{
	COObject *serverChild1 = [[serverBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[[serverBranch rootObject] addObject: serverChild1];
	[ctx commit];
	return serverChild1;
}

- (COObject *) addAndCommitClientChild
{
	COObject *clientChild1 = [[clientBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[[clientBranch rootObject] addObject: clientChild1];
	[clientCtx commit];
	return clientChild1;
}

- (void) testServerEdit
{
	COObject *serverChild1 = [self addAndCommitServerChild];
	
	[transport deliverMessagesToClient];
	
	UKIntsEqual(1, [[[clientBranch rootObject] contents] count]);
	COObject *clientChild1 = [[clientBranch rootObject] contents][0];
	UKObjectsEqual([[serverBranch rootObject] UUID], [[clientBranch rootObject] UUID]);
	UKObjectsEqual([serverChild1 UUID], [clientChild1 UUID]);
}

- (void) testClientEdit
{
	COObject *clientChild1 = [self addAndCommitClientChild];
	
	[transport deliverMessagesToServer];
	
	UKIntsEqual(1, [[[serverBranch rootObject] contents] count]);
	COObject *serverChild1 = [[serverBranch rootObject] contents][0];
	UKObjectsEqual([[clientBranch rootObject] UUID], [[serverBranch rootObject] UUID]);
	UKObjectsEqual([clientChild1 UUID], [serverChild1 UUID]);
}

#if 0
- (void) testServerAndClientEdit
{
	COObject *serverChild1 = [self addAndCommitServerChild];
	COObject *clientChild1 = [self addAndCommitClientChild];
	
	[transport deliverMessagesToServer];
	
	UKIntsEqual(2, [[[serverBranch rootObject] contents] count]);
	
	// N.B. I'm assuming that since the client's child was merged in afterwards,
	// it was inserted at position 0.
	UKObjectsEqual(clientChild1, [[serverBranch rootObject] contents][0]);
	UKObjectsSame(serverChild1, [[serverBranch rootObject] contents][1]);
	
	[transport deliverMessagesToClient];
	
	UKIntsEqual(2, [[[clientBranch rootObject] contents] count]);
	UKObjectsSame(clientChild1, [[clientBranch rootObject] contents][0]);
	UKObjectsEqual(serverChild1, [[clientBranch rootObject] contents][1]);
}

- (void) testClientAndServerEdit
{
	COObject *serverChild1 = [self addAndCommitServerChild];
	COObject *clientChild1 = [self addAndCommitClientChild];
	
	[transport deliverMessagesToClient];
	
	UKIntsEqual(2, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(serverChild1, [[clientBranch rootObject] contents][0]);
	UKObjectsSame(clientChild1, [[clientBranch rootObject] contents][1]);

	
	[transport deliverMessagesToServer];
	
	UKIntsEqual(2, [[[serverBranch rootObject] contents] count]);
	UKObjectsSame(serverChild1, [[serverBranch rootObject] contents][0]);
	UKObjectsEqual(clientChild1, [[serverBranch rootObject] contents][1]);
}
#endif
@end

