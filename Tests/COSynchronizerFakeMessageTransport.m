#import <UnitKit/UnitKit.h>
#import "COSynchronizerFakeMessageTransport.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

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
		if ([self deliverMessagesToClient: clientID])
		{
			deliveredAny = YES;
		}
	}
	return deliveredAny;
}

- (BOOL) deliverMessagesToClient: (NSString *)clientID
{
	BOOL deliveredAny = NO;
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

