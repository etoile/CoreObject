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

- (void) addClient: (COSynchronizerClient *)aClient;

@property (nonatomic, readonly, strong) COSynchronizerServer *server;

- (void) deliverMessages;

- (NSArray *) serverMessages;
- (NSArray *) messagesForClient: (NSString *)anID;

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
		if ([message isKindOfClass: [COSynchronizerPushedRevisionsFromClientMessage class]])
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
	BOOL deliveredAny;
	NSUInteger i = 0;
	do
	{
		deliveredAny = NO;
		
		if (i >= 10)
		{
			// Catch infinite loops
			UKFail();
			return;
		}
		
		if ([self deliverMessagesToClient])
			deliveredAny = YES;
		
		if([self deliverMessagesToServer])
			deliveredAny = YES;
		
		i++;
	}
	while (deliveredAny == YES);
}

- (void) addClient: (COSynchronizerClient *)aClient
{
	[server addClientID: aClient.clientID];
	
	ETAssert([clientMessagesForID[aClient.clientID] count] == 1);
	ETAssert([clientMessagesForID[aClient.clientID][0] isKindOfClass: [COSynchronizerPersistentRootInfoToClientMessage class]]);
	COSynchronizerPersistentRootInfoToClientMessage *setupMessage = clientMessagesForID[aClient.clientID][0];
	[clientMessagesForID[aClient.clientID] removeAllObjects];
	
	[aClient handleSetupMessage: setupMessage];

	aClient.delegate = self;
	clientForID[aClient.clientID] = aClient;
}

- (NSArray *) serverMessages
{
	return [serverMessages copy];
}

- (NSArray *) messagesForClient: (NSString *)anID
{
	return [[clientMessagesForID objectForKey: anID] copy];
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
	client = [[COSynchronizerClient alloc] initWithClientID: @"client" editingContext: clientCtx];
	
	[transport addClient: client];
	
	clientPersistentRoot = client.persistentRoot;
	clientBranch = client.branch;
	
	ETAssert(clientPersistentRoot != nil);
	ETAssert(clientBranch != nil);
	
	return self;
}

- (OutlineItem *) addAndCommitServerChild
{
	OutlineItem *serverChild1 = [[serverBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[[serverBranch rootObject] addObject: serverChild1];
	[ctx commit];
	return serverChild1;
}

- (OutlineItem *) addAndCommitClientChild
{
	OutlineItem *clientChild1 = [[clientBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[[clientBranch rootObject] addObject: clientChild1];
	[clientCtx commit];
	return clientChild1;
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

- (NSArray *)serverMessages
{
	return [transport serverMessages];
}

- (NSArray *)clientMessages
{
	return [transport messagesForClient: client.clientID];
}

- (void) testClientEdit
{
	OutlineItem *clientChild1 = [self addAndCommitClientChild];
	
	UKIntsEqual(1, [[self serverMessages] count]);
	UKObjectKindOf([self serverMessages][0], COSynchronizerPushedRevisionsFromClientMessage);
	UKIntsEqual(0, [[self clientMessages] count]);
	
	// Server should merge in client's changes, and send a push response back to the client
	[transport deliverMessagesToServer];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerResponseToClientForSentRevisionsMessage);
	
	UKIntsEqual(1, [[[serverBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1), SA([[serverBranch rootObject] contents]));
	
	// Deliver the response to the client
	[transport deliverMessagesToClient];
	
	// Should not send anything more to server
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
}

- (void) testServerEdit
{
	OutlineItem *serverChild1 = [self addAndCommitServerChild];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage);
	
	// Deliver push to client
	[transport deliverMessagesToClient];
	
	UKIntsEqual(1, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(serverChild1), SA([[clientBranch rootObject] contents]));
	
	// No more messages
	UKIntsEqual(0, [[self clientMessages] count]);
	UKIntsEqual(0, [[self serverMessages] count]);
}

- (void) testClientAndServerEdit
{
	OutlineItem *serverChild1 = [self addAndCommitServerChild];
	OutlineItem *clientChild1 = [self addAndCommitClientChild];
	
	UKIntsEqual(1, [[self serverMessages] count]);
	UKObjectKindOf([self serverMessages][0], COSynchronizerPushedRevisionsFromClientMessage);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage);

	// Client should ignore this messages, because it's currently waiting for the response to its push
	[transport deliverMessagesToClient];
	
	UKIntsEqual(0, [[self clientMessages] count]);
	
	UKIntsEqual(1, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1), SA([[clientBranch rootObject] contents]));
	
	// Server should merge in client's changes, and send a push response back to the client
	[transport deliverMessagesToServer];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerResponseToClientForSentRevisionsMessage);
	
	UKIntsEqual(2, [[[serverBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), SA([[serverBranch rootObject] contents]));
	
	// Deliver the response to the client
	[transport deliverMessagesToClient];
	
	// Should not send anything more to server
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
		
	UKIntsEqual(2, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), SA([[clientBranch rootObject] contents]));
}

- (void) testServerAndClientEdit
{
	OutlineItem *serverChild1 = [self addAndCommitServerChild];
	OutlineItem *clientChild1 = [self addAndCommitClientChild];
	
	UKIntsEqual(1, [[self serverMessages] count]);
	{
		COSynchronizerPushedRevisionsFromClientMessage *serverMessage0 = [self serverMessages][0];
		UKObjectKindOf(serverMessage0, COSynchronizerPushedRevisionsFromClientMessage);
		UKObjectsEqual(client.clientID, serverMessage0.clientID);
		UKIntsEqual(1, [serverMessage0.revisions count]);
		UKObjectsEqual([[[clientChild1 revision] parentRevision] UUID], serverMessage0.lastRevisionUUIDSentByServer);
		
		COSynchronizerRevision *serverMessage0Rev0 = serverMessage0.revisions[0];
		UKObjectsEqual([[clientChild1 revision] UUID], serverMessage0Rev0.revisionUUID);
		UKObjectsEqual([[[clientChild1 revision] parentRevision] UUID], serverMessage0Rev0.parentRevisionUUID);
	}
	
	UKIntsEqual(1, [[self clientMessages] count]);
	{
		COSynchronizerPushedRevisionsToClientMessage *clientMessage0 = [self clientMessages][0];
		UKObjectKindOf(clientMessage0, COSynchronizerPushedRevisionsToClientMessage);
		UKIntsEqual(1, [clientMessage0.revisions count]);
		
		COSynchronizerRevision *clientMessage0Rev0 = clientMessage0.revisions[0];
		UKObjectsEqual([[serverChild1 revision] UUID], clientMessage0Rev0.revisionUUID);
		UKObjectsEqual([[[serverChild1 revision] parentRevision] UUID], clientMessage0Rev0.parentRevisionUUID);
	}
	
	// Server should merge in client's changes, and send a push response back to the client
	[transport deliverMessagesToServer];
	
	UKIntsEqual(2, [[[serverBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), SA([[serverBranch rootObject] contents]));
	
	UKIntsEqual(0, [[self serverMessages] count]);
	
	UKIntsEqual(2, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage);
	{
		COSynchronizerResponseToClientForSentRevisionsMessage *clientMessage1 = [self clientMessages][1];
		UKObjectKindOf(clientMessage1, COSynchronizerResponseToClientForSentRevisionsMessage);
		UKObjectsEqual([[clientChild1 revision] UUID], clientMessage1.lastRevisionUUIDSentByClient);
		// Server should be sending [[serverChild1 revision] parentRevision], as well as the clients changes rebased on to that ([serverChild1 revision])
		UKIntsEqual(2, [clientMessage1.revisions count]);
		
		COSynchronizerRevision *clientMessage1Rev0 = clientMessage1.revisions[0];
		UKObjectsEqual([[[[serverChild1 revision] parentRevision] parentRevision] UUID], clientMessage1Rev0.parentRevisionUUID);
		UKObjectsEqual([[[serverChild1 revision] parentRevision] UUID], clientMessage1Rev0.revisionUUID);
		
		COSynchronizerRevision *clientMessage1Rev1 = clientMessage1.revisions[1];
		UKObjectsEqual([[[serverChild1 revision] parentRevision] UUID], clientMessage1Rev1.parentRevisionUUID);
		UKObjectsEqual([[serverChild1 revision] UUID], clientMessage1Rev1.revisionUUID);
	}

	// Deliver the response to the client
	[transport deliverMessagesToClient];
	
	// Should not send anything more to server
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
	
	UKIntsEqual(2, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), SA([[clientBranch rootObject] contents]));
}

- (void) testLocalClientCommitsAfterPushingToServer
{
	OutlineItem *serverChild1 = [self addAndCommitServerChild];
	OutlineItem *clientChild1 = [self addAndCommitClientChild];
	
	UKIntsEqual(1, [[self serverMessages] count]);
	UKObjectKindOf([self serverMessages][0], COSynchronizerPushedRevisionsFromClientMessage);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage);
	
	// Server should merge in client's changes, and send a push response back to the client
	[transport deliverMessagesToServer];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	
	UKIntsEqual(2, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage); /* Will be ignored by client */
	UKObjectKindOf([self clientMessages][1], COSynchronizerResponseToClientForSentRevisionsMessage);
	
	UKIntsEqual(2, [[[serverBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), SA([[serverBranch rootObject] contents]));
	
	// Before the merged changes arrives at the client, make another commit on the client
	
	[[clientBranch rootObject] setLabel: @"more changes"];
	[clientPersistentRoot commit];
	
	// This should not produce any more messages
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(2, [[self clientMessages] count]);
		
	// Deliver the merge response to the client
	[transport deliverMessagesToClient];
	
	// The client should push back the @"more changes" change to the server
	
	UKIntsEqual(1, [[self serverMessages] count]);
	UKObjectKindOf([self serverMessages][0], COSynchronizerPushedRevisionsFromClientMessage);
	UKIntsEqual(0, [[self clientMessages] count]);
	
	[transport deliverMessagesToServer];
	
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerResponseToClientForSentRevisionsMessage);
	
	UKObjectsEqual(@"more changes", [[serverBranch rootObject] label]);
	
	[transport deliverMessagesToClient];
	
	// Should not send anything more
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
}


@end

