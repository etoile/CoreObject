/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestSynchronizerJSONTransportDelegate : NSObject <COSynchronizerJSONClientDelegate, COSynchronizerJSONServerDelegate>

@property (nonatomic, readwrite, weak) COSynchronizerJSONServer *server;
@property (nonatomic, readwrite, weak) COSynchronizerJSONClient *client1;
@property (nonatomic, readwrite, weak) COSynchronizerJSONClient *client2;

@end


@implementation TestSynchronizerJSONTransportDelegate

@synthesize server, client1, client2;

- (void)JSONServer: (COSynchronizerJSONServer *)server
          sendText: (NSString *)text
          toClient: (NSString *)client
{
    ETAssert(self.client1 != nil);
    ETAssert(self.client2 != nil);
    if ([client isEqualToString: @"client1"])
    {
        [self.client1 receiveTextFromServer: text];
    }
    else if ([client isEqualToString: @"client2"])
    {
        [self.client2 receiveTextFromServer: text];
    }
    else
    {
        ETAssertUnreachable();
    }
}

- (void)JSONClient: (COSynchronizerJSONClient *)client sendTextToServer: (NSString *)text
{
    ETAssert(self.server != nil);
    [self.server receiveText: text fromClient: client.client.clientID];
}

- (void)JSONClient: (COSynchronizerJSONClient *)client didStartSharingOnBranch: (COBranch *)aBranch
{
}

@end


@interface TestSynchronizerJSONTransport : EditingContextTestCase <UKTest>
{
    TestSynchronizerJSONTransportDelegate *transportDelegate;
    COSynchronizerJSONServer *jsonServer;
    COSynchronizerJSONClient *jsonClient1;
    COSynchronizerJSONClient *jsonClient2;

    COSynchronizerServer *server;
    COSynchronizerClient *client1;
    COSynchronizerClient *client2;

    COEditingContext *client1Ctx;
    COEditingContext *client2Ctx;
}

@end

#define CLIENT1_STORE_URL [[SQLiteStoreTestCase temporaryURLForTestStorage] URLByAppendingPathComponent: @"TestStore2.sqlite"]
#define CLIENT2_STORE_URL [[SQLiteStoreTestCase temporaryURLForTestStorage] URLByAppendingPathComponent: @"TestStore3.sqlite"]

@implementation TestSynchronizerJSONTransport

- (instancetype)init
{
    SUPERINIT;

    [[[COSQLiteStore alloc] initWithURL: CLIENT1_STORE_URL] clearStore];
    [[[COSQLiteStore alloc] initWithURL: CLIENT2_STORE_URL] clearStore];

    COPersistentRoot *serverPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupNoOpposite"];
    [ctx commit];

    server = [[COSynchronizerServer alloc] initWithBranch: serverPersistentRoot.currentBranch];

    client1Ctx = [COEditingContext contextWithURL: CLIENT1_STORE_URL];
    client1 = [[COSynchronizerClient alloc] initWithClientID: @"client1"
                                              editingContext: client1Ctx];

    client2Ctx = [COEditingContext contextWithURL: CLIENT2_STORE_URL];
    client2 = [[COSynchronizerClient alloc] initWithClientID: @"client2"
                                              editingContext: client2Ctx];

    // Setup JSON stuff

    transportDelegate = [TestSynchronizerJSONTransportDelegate new];
    jsonServer = [COSynchronizerJSONServer new];
    jsonClient1 = [COSynchronizerJSONClient new];
    jsonClient2 = [COSynchronizerJSONClient new];

    transportDelegate.server = jsonServer;
    transportDelegate.client1 = jsonClient1;
    transportDelegate.client2 = jsonClient2;

    jsonServer.delegate = transportDelegate;
    jsonServer.server = server;

    jsonClient1.delegate = transportDelegate;
    jsonClient1.client = client1;

    jsonClient2.delegate = transportDelegate;
    jsonClient2.client = client2;

    server.delegate = jsonServer;
    client1.delegate = jsonClient1;
    client2.delegate = jsonClient2;

    // Tell the server about the clients

    ETAssert(client1.persistentRoot == nil);
    ETAssert(client2.persistentRoot == nil);

    [server addClientID: @"client1"];
    [server addClientID: @"client2"];

    ETAssert(client1.persistentRoot != nil);
    ETAssert(client2.persistentRoot != nil);

    return self;
}

- (UnorderedGroupNoOpposite *)addAndCommitServerChild
{
    UnorderedGroupNoOpposite *serverChild1 = [server.persistentRoot.objectGraphContext insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
    [[server.persistentRoot.rootObject mutableSetValueForKey: @"contents"] addObject: serverChild1];
    [server.persistentRoot commit];
    return serverChild1;
}

- (UnorderedGroupNoOpposite *)addAndCommitClient1Child
{
    UnorderedGroupNoOpposite *clientChild1 = [client1.persistentRoot.objectGraphContext insertObjectWithEntityName: @"UnorderedGroupNoOpposite"];
    [[client1.persistentRoot.rootObject mutableSetValueForKey: @"contents"] addObject: clientChild1];
    [client1.persistentRoot commit];
    return clientChild1;
}

- (void)testServerEditWhilePausedAndClientReceivingWhilePaused
{
    jsonClient1.paused = YES;
    jsonServer.paused = YES;

    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];

    jsonServer.paused = NO;

    UKIntsEqual(0, [[client1.persistentRoot.rootObject contents] count]);

    jsonClient1.paused = NO;

    UKIntsEqual(1, [[client1.persistentRoot.rootObject contents] count]);
}

- (void)testClientEditWhilePausedAndServerReceivingWhilePaused
{
    jsonClient1.paused = YES;
    jsonServer.paused = YES;

    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClient1Child];

    jsonClient1.paused = NO;

    UKIntsEqual(0, [[server.persistentRoot.rootObject contents] count]);

    jsonServer.paused = NO;

    UKIntsEqual(1, [[server.persistentRoot.rootObject contents] count]);
}

@end
