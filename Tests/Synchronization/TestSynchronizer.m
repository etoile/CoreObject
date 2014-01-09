/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COSynchronizerFakeMessageTransport.h"
#import "TestAttributedStringCommon.h"

#define CLIENT_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore2.sqlite" stringByExpandingTildeInPath]]

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
	
	serverPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupNoOpposite"];
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

- (UnorderedGroupNoOpposite *) addAndCommitServerChild
{
	UnorderedGroupNoOpposite *serverChild1 = [[serverBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.UnorderedGroupNoOpposite"];
	[[[serverBranch rootObject] mutableSetValueForKey: @"contents"] addObject: serverChild1];
	[ctx commit];
	return serverChild1;
}

- (UnorderedGroupNoOpposite *) addAndCommitClientChild
{
	UnorderedGroupNoOpposite *clientChild1 = [[clientBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.UnorderedGroupNoOpposite"];
	[[[clientBranch rootObject] mutableSetValueForKey: @"contents"] addObject: clientChild1];
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
	UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];
	
	UKIntsEqual(1, [[self serverMessages] count]);
	UKObjectKindOf([self serverMessages][0], COSynchronizerPushedRevisionsFromClientMessage);
	UKIntsEqual(0, [[self clientMessages] count]);
	
	// Server should merge in client's changes, and send a push response back to the client
	[transport deliverMessagesToServer];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerResponseToClientForSentRevisionsMessage);
	
	UKIntsEqual(1, [[[serverBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1), [[serverBranch rootObject] contents]);
	
	// Deliver the response to the client
	[transport deliverMessagesToClient];
	
	// Should not send anything more to server
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
}

- (void) testServerEdit
{
	UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage);
	
	// Deliver push to client
	[transport deliverMessagesToClient];
	
	UKIntsEqual(1, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(serverChild1), [[clientBranch rootObject] contents]);
	
	// No more messages
	UKIntsEqual(0, [[self clientMessages] count]);
	UKIntsEqual(0, [[self serverMessages] count]);
}

- (void) testClientAndServerEdit
{
	UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
	UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];
	
	UKIntsEqual(1, [[self serverMessages] count]);
	UKObjectKindOf([self serverMessages][0], COSynchronizerPushedRevisionsFromClientMessage);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerPushedRevisionsToClientMessage);

	// Client should ignore this messages, because it's currently waiting for the response to its push
	[transport deliverMessagesToClient];
	
	UKIntsEqual(0, [[self clientMessages] count]);
	
	UKIntsEqual(1, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1), [[clientBranch rootObject] contents]);
	
	// Server should merge in client's changes, and send a push response back to the client
	[transport deliverMessagesToServer];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	
	UKIntsEqual(1, [[self clientMessages] count]);
	UKObjectKindOf([self clientMessages][0], COSynchronizerResponseToClientForSentRevisionsMessage);
	
	UKIntsEqual(2, [[[serverBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), [[serverBranch rootObject] contents]);
	
	// Deliver the response to the client
	[transport deliverMessagesToClient];
	
	// Should not send anything more to server
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
		
	UKIntsEqual(2, [[[clientBranch rootObject] contents] count]);
	UKObjectsEqual(S(clientChild1, serverChild1), [[clientBranch rootObject] contents]);
}

- (void) testServerAndClientEdit
{
	UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
	UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];
	
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
	UKObjectsEqual(S(clientChild1, serverChild1), [[serverBranch rootObject] contents]);
	
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
	UKObjectsEqual(S(clientChild1, serverChild1), [[clientBranch rootObject] contents]);
}

- (void) testLocalClientCommitsAfterPushingToServer
{
	UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
	UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];
	
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
	UKObjectsEqual(S(clientChild1, serverChild1), [[serverBranch rootObject] contents]);
	
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

- (void) testBasicServerRevert
{
	[[serverBranch rootObject] setLabel: @"revertThis"];
	[serverPersistentRoot commit];
	
	[transport deliverMessagesToClient];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
	UKObjectsEqual(@"revertThis", [[clientBranch rootObject] label]);
	
	[serverBranch setCurrentRevision: [[serverBranch currentRevision] parentRevision]];
	UKRaisesException([serverPersistentRoot commit]);
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
}

- (void) testBasicClientRevert
{
	[[serverBranch rootObject] setLabel: @"revertThis"];
	[serverPersistentRoot commit];
	
	[transport deliverMessagesToClient];
	
	UKIntsEqual(0, [[self serverMessages] count]);
	UKIntsEqual(0, [[self clientMessages] count]);
	UKObjectsEqual(@"revertThis", [[clientBranch rootObject] label]);
	
	[clientBranch setCurrentRevision: [[clientBranch currentRevision] parentRevision]];
	UKRaisesException([clientPersistentRoot commit]);

	// No more messages
	
	UKIntsEqual(0, [[self clientMessages] count]);
	UKIntsEqual(0, [[self serverMessages] count]);
}

- (void) testMergeOverlappingAttributeAdditions
{
	/*
	 server:
	 
	 "Hello"
	 
	 */
		
	COAttributedString *serverStr = [[COAttributedString alloc] initWithObjectGraphContext: [serverBranch objectGraphContext]];
	[[serverBranch rootObject] setContents: S(serverStr)];
	[self appendString: @"Hello" htmlCode: nil toAttributedString: serverStr];
	[serverPersistentRoot commit];
	
	[transport deliverMessagesToClient];
	
	/*
	 client:
	 
	 "Hello"
	  ^^^^
	 bold
	 
	 */
	
	COAttributedString *clientStr = [[[clientBranch rootObject] contents] anyObject];
	COAttributedStringWrapper *clientWrapper = [[COAttributedStringWrapper alloc] initWithBacking: clientStr];
	[self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0,4) inTextStorage: clientWrapper];
	[clientPersistentRoot commit];
	
	/*
	 server:
	 
	 "Hello"
	    ^^^
	 underline
	 
	 */
	
	COAttributedStringWrapper *serverWrapper = [[COAttributedStringWrapper alloc] initWithBacking: serverStr];
	[serverWrapper setAttributes: @{ NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle) } range: NSMakeRange(2, 3)];
	[serverPersistentRoot commit];
	
	[transport deliverMessagesToServer];
	
	
	/*
	 ctxExpected:
	 
	 "Hello"
	  ^^^^
	 bold
	    ^^^
	 underline
	 
	 */
	
	UKObjectsEqual(A(@"He",    @"ll",         @"o"), [serverStr valueForKeyPath: @"chunks.text"]);
	UKObjectsEqual(A(S(@"b"),  S(@"b", @"u"), S(@"u")), [serverStr valueForKeyPath: @"chunks.attributes.htmlCode"]);
}

@end

