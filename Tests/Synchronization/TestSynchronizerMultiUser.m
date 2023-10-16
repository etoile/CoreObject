/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COSynchronizerFakeMessageTransport.h"

#define CLIENT1_STORE_URL [[SQLiteStoreTestCase temporaryURLForTestStorage]  URLByAppendingPathComponent: @"TestStore2.sqlite"]
#define CLIENT2_STORE_URL [[SQLiteStoreTestCase temporaryURLForTestStorage] URLByAppendingPathComponent: @"TestStore3.sqlite"]

@interface TestSynchronizerMultiUser : EditingContextTestCase <UKTest>
{
    COSynchronizerServer *server;
    COPersistentRoot *serverPersistentRoot;
    COBranch *serverBranch;

    FakeMessageTransport *transport;

    COSynchronizerClient *client1;
    COEditingContext *client1Ctx;
    COPersistentRoot *client1PersistentRoot;
    COBranch *client1Branch;

    COSynchronizerClient *client2;
    COEditingContext *client2Ctx;
    COPersistentRoot *client2PersistentRoot;
    COBranch *client2Branch;
}

@end


@implementation TestSynchronizerMultiUser

- (instancetype)init
{
    SUPERINIT;

    COSQLiteStore *client1Store = [[COSQLiteStore alloc] initWithURL: CLIENT1_STORE_URL];
    COSQLiteStore *client2Store = [[COSQLiteStore alloc] initWithURL: CLIENT2_STORE_URL];
    
    [client1Store clearStore];
    [client2Store clearStore];
    client1Store = nil;
    client2Store = nil;

    serverPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    serverBranch = serverPersistentRoot.currentBranch;
    [ctx commit];

    server = [[COSynchronizerServer alloc] initWithBranch: serverBranch];
    transport = [[FakeMessageTransport alloc] initWithSynchronizerServer: server];

    client1Ctx = [COEditingContext contextWithURL: CLIENT1_STORE_URL];
    client1 = [[COSynchronizerClient alloc] initWithClientID: @"client1"
                                              editingContext: client1Ctx];

    [transport addClient: client1];

    client1PersistentRoot = client1.persistentRoot;
    client1Branch = client1.branch;

    client2Ctx = [COEditingContext contextWithURL: CLIENT2_STORE_URL];
    client2 = [[COSynchronizerClient alloc] initWithClientID: @"client2"
                                              editingContext: client2Ctx];

    [transport addClient: client2];

    client2PersistentRoot = client2.persistentRoot;
    client2Branch = client2.branch;

    ETAssert(client1PersistentRoot != nil);
    ETAssert(client1Branch != nil);
    ETAssert(client2PersistentRoot != nil);
    ETAssert(client2Branch != nil);

    return self;
}

- (void)dealloc
{
    NSError *error = nil;

    // If objects referencing client store are not deallocated before removing the store file, the
    // store remains around until dealloc ends and SQLite complains: 'vnode unlinked while in use'.
    transport = nil;
    server = nil;
    client1 = nil;
    client1Ctx = nil;
    client2 = nil;
    client2Ctx = nil;
    [[NSFileManager defaultManager] removeItemAtURL: CLIENT1_STORE_URL error: &error];
    ETAssert(error == nil);
    [[NSFileManager defaultManager] removeItemAtURL: CLIENT2_STORE_URL error: NULL];
    ETAssert(error == nil);
}

- (OutlineItem *)addAndCommitServerChild
{
    OutlineItem *serverChild = [serverBranch.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    [serverBranch.rootObject addObject: serverChild];
    [ctx commit];
    return serverChild;
}

- (OutlineItem *)addAndCommitClient1Child
{
    OutlineItem *clientChild = [client1Branch.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    [client1Branch.rootObject addObject: clientChild];
    [client1Ctx commit];
    return clientChild;
}

- (OutlineItem *)addAndCommitClient2Child
{
    OutlineItem *clientChild = [client2Branch.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    [client2Branch.rootObject addObject: clientChild];
    [client2Ctx commit];
    return clientChild;
}

- (NSArray *)serverMessages
{
    return transport.serverMessages;
}

- (NSArray *)client1Messages
{
    return [transport messagesForClient: @"client1"];
}

- (NSArray *)client2Messages
{
    return [transport messagesForClient: @"client2"];
}

- (void)testClientsEdit
{
    OutlineItem *client1Child = [self addAndCommitClient1Child];
    OutlineItem *client2Child = [self addAndCommitClient2Child];

    UKIntsEqual(2, self.serverMessages.count);
    UKObjectKindOf(self.serverMessages[0], COSynchronizerPushedRevisionsFromClientMessage);
    UKObjectKindOf(self.serverMessages[0], COSynchronizerPushedRevisionsFromClientMessage);
    UKIntsEqual(0, [self client1Messages].count);
    UKIntsEqual(0, [self client2Messages].count);

    // Server should merge in client's changes in the order they were made [client1, client2],
    // and send a push response back to each of the clients
    [transport deliverMessagesToServer];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(2, [self client1Messages].count);
    UKObjectKindOf([self client1Messages][0],
                   COSynchronizerResponseToClientForSentRevisionsMessage);
    UKObjectKindOf([self client1Messages][1], COSynchronizerPushedRevisionsToClientMessage);
    UKIntsEqual(2, [self client2Messages].count);
    /* This message is sent to client2 when client1's push message is handled, before the
       server sees client2's push message. Client2 will ignore it. */
    UKObjectKindOf([self client2Messages][0], COSynchronizerPushedRevisionsToClientMessage);
    /* The response to client2 for client2's push */
    UKObjectKindOf([self client2Messages][1],
                   COSynchronizerResponseToClientForSentRevisionsMessage);

    [transport deliverMessagesToClient: @"client1"];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, [self client1Messages].count);
    UKIntsEqual(2, [self client2Messages].count);

    UKIntsEqual(2, [[client1Branch.rootObject contents] count]);
    UKObjectsEqual(S(client1Child.UUID, client2Child.UUID),
                   SA([client1Branch.rootObject valueForKeyPath: @"contents.UUID"]));

    [transport deliverMessagesToClient: @"client2"];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, [self client1Messages].count);
    UKIntsEqual(0, [self client2Messages].count);

    UKIntsEqual(2, [[client2Branch.rootObject contents] count]);
    UKObjectsEqual(S(client1Child.UUID, client2Child.UUID),
                   SA([client2Branch.rootObject valueForKeyPath: @"contents.UUID"]));
}

@end

