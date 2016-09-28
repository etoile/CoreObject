/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  September 2014
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import "COSynchronizerImmediateMessageTransport.h"

#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

@implementation ImmediateMessageTransport

@synthesize server = server;

- (id)initWithSynchronizerServer: (COSynchronizerServer *)aServer
{
    SUPERINIT;
    server = aServer;
    server.delegate = self;
    clientForID = [NSMutableDictionary new];
    return self;
}

- (void)sendPushToServer: (COSynchronizerPushedRevisionsFromClientMessage *)message
{
    ETAssert([message isKindOfClass: [COSynchronizerPushedRevisionsFromClientMessage class]]);
    [server handlePushedRevisionsFromClient: message];
}

- (void)sendResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)message
                   toClient: (NSString *)clientID
{
    COSynchronizerClient *client = clientForID[clientID];

    ETAssert([message isKindOfClass: [COSynchronizerResponseToClientForSentRevisionsMessage class]]);
    ETAssert(client != nil);

    [client handleResponseMessage: message];

}

- (void)sendPushedRevisions: (COSynchronizerPushedRevisionsToClientMessage *)message
                  toClients: (NSArray *)clients
{
    for (NSString *clientID in clients)
    {
        COSynchronizerClient *client = clientForID[clientID];

        ETAssert([message isKindOfClass: [COSynchronizerPushedRevisionsToClientMessage class]]);
        ETAssert(client != nil);

        [client handlePushMessage: message];
    }
}

- (void)sendPersistentRootInfoMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
                             toClient: (NSString *)clientID
{
    COSynchronizerClient *client = clientForID[clientID];

    ETAssert([message isKindOfClass: [COSynchronizerPersistentRootInfoToClientMessage class]]);
    ETAssert(client != nil);

    [client handleSetupMessage: message];
}

- (void)addClient: (COSynchronizerClient *)aClient
{
    clientForID[aClient.clientID] = aClient;
    aClient.delegate = self;

    [server addClientID: aClient.clientID];
}

- (NSArray *)serverMessages
{
    ETAssertUnreachable();
    return nil;
}

- (NSArray *)messagesForClient: (NSString *)anID
{
    ETAssertUnreachable();
    return nil;
}

- (BOOL)deliverMessagesToServer
{
    ETAssertUnreachable();
    return NO;
}

- (BOOL)deliverMessagesToClient
{
    ETAssertUnreachable();
    return NO;
}

@end

