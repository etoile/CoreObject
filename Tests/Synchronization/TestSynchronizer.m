/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "TestSynchronizerCommon.h"

@interface TestSynchronizer : TestSynchronizerCommon <UKTest>
@end


@implementation TestSynchronizer

- (void)testPersistentRootMetadataReplicated
{
    UKObjectsEqual(self.persistentRootMetadataForTest, clientPersistentRoot.metadata);
}

- (void)testBranchMetadataReplicated
{
    UKObjectsEqual(self.branchMetadataForTest, clientBranch.metadata);
}

- (void)testBasicReplicationToClient
{
    UKNotNil(clientPersistentRoot);
    UKNotNil(clientBranch);
    UKNotNil(clientPersistentRoot.currentBranch);
    UKObjectsSame(clientBranch, clientPersistentRoot.currentBranch);
    UKObjectsEqual(serverPersistentRoot.UUID, clientPersistentRoot.UUID);
    UKObjectsEqual(serverBranch.UUID, clientBranch.UUID);
    UKObjectsEqual([serverBranch.rootObject UUID], [clientBranch.rootObject UUID]);
}

- (void)testClientEdit
{
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];

    UKIntsEqual(1, self.serverMessages.count);
    UKObjectKindOf(self.serverMessages[0], COSynchronizerPushedRevisionsFromClientMessage);
    UKIntsEqual(0, self.clientMessages.count);

    // Server should merge in client's changes, and send a push response back to the client
    [transport deliverMessagesToServer];

    UKIntsEqual(0, self.serverMessages.count);

    UKIntsEqual(1, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerResponseToClientForSentRevisionsMessage);

    UKIntsEqual(1, [[serverBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID),
                   [serverBranch.rootObject valueForKeyPath: @"contents.UUID"]);

    // Deliver the response to the client
    [transport deliverMessagesToClient];

    // Should not send anything more to server
    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);
}

- (void)testServerEdit
{
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(1, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerPushedRevisionsToClientMessage);

    // Deliver push to client
    [transport deliverMessagesToClient];

    UKIntsEqual(1, [[clientBranch.rootObject contents] count]);
    UKObjectsEqual(S(serverChild1.UUID),
                   [clientBranch.rootObject valueForKeyPath: @"contents.UUID"]);

    // No more messages
    UKIntsEqual(0, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);
}

- (void)testClientAndServerEdit
{
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];

    UKIntsEqual(1, self.serverMessages.count);
    UKObjectKindOf(self.serverMessages[0], COSynchronizerPushedRevisionsFromClientMessage);

    UKIntsEqual(1, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerPushedRevisionsToClientMessage);

    // Client should ignore this messages, because it's currently waiting for the response to its push
    [transport deliverMessagesToClient];

    UKIntsEqual(0, self.clientMessages.count);

    UKIntsEqual(1, [[clientBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1), [clientBranch.rootObject contents]);

    // Server should merge in client's changes, and send a push response back to the client
    [transport deliverMessagesToServer];

    UKIntsEqual(0, self.serverMessages.count);

    UKIntsEqual(1, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerResponseToClientForSentRevisionsMessage);

    UKIntsEqual(2, [[serverBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [serverBranch.rootObject valueForKeyPath: @"contents.UUID"]);

    // Deliver the response to the client
    [transport deliverMessagesToClient];

    // Should not send anything more to server
    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);

    UKIntsEqual(2, [[clientBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [clientBranch.rootObject valueForKeyPath: @"contents.UUID"]);
}

- (void)testServerAndClientEdit
{
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];

    UKIntsEqual(1, self.serverMessages.count);
    {
        COSynchronizerPushedRevisionsFromClientMessage *serverMessage0 = self.serverMessages[0];
        UKObjectKindOf(serverMessage0, COSynchronizerPushedRevisionsFromClientMessage);
        UKObjectsEqual(client.clientID, serverMessage0.clientID);
        UKIntsEqual(1, serverMessage0.revisions.count);
        UKObjectsEqual(clientChild1.revision.parentRevision.UUID,
                       serverMessage0.lastRevisionUUIDSentByServer);

        COSynchronizerRevision *serverMessage0Rev0 = serverMessage0.revisions[0];
        UKObjectsEqual(clientChild1.revision.UUID, serverMessage0Rev0.revisionUUID);
        UKObjectsEqual(clientChild1.revision.parentRevision.UUID,
                       serverMessage0Rev0.parentRevisionUUID);
    }

    UKIntsEqual(1, self.clientMessages.count);
    {
        COSynchronizerPushedRevisionsToClientMessage *clientMessage0 = self.clientMessages[0];
        UKObjectKindOf(clientMessage0, COSynchronizerPushedRevisionsToClientMessage);
        UKIntsEqual(1, clientMessage0.revisions.count);

        COSynchronizerRevision *clientMessage0Rev0 = clientMessage0.revisions[0];
        UKObjectsEqual(serverChild1.revision.UUID, clientMessage0Rev0.revisionUUID);
        UKObjectsEqual(serverChild1.revision.parentRevision.UUID,
                       clientMessage0Rev0.parentRevisionUUID);
    }

    // Server should merge in client's changes, and send a push response back to the client
    [transport deliverMessagesToServer];

    UKIntsEqual(2, [[serverBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [serverBranch.rootObject valueForKeyPath: @"contents.UUID"]);

    UKIntsEqual(0, self.serverMessages.count);

    UKIntsEqual(2, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerPushedRevisionsToClientMessage);
    {
        COSynchronizerResponseToClientForSentRevisionsMessage *clientMessage1 = self.clientMessages[1];
        UKObjectKindOf(clientMessage1, COSynchronizerResponseToClientForSentRevisionsMessage);
        UKObjectsEqual(clientChild1.revision.UUID, clientMessage1.lastRevisionUUIDSentByClient);
        // Server should be sending serverChild1.revision.parentRevision, as well as the clients changes rebased on to that (serverChild1.revision)
        UKIntsEqual(2, clientMessage1.revisions.count);

        COSynchronizerRevision *clientMessage1Rev0 = clientMessage1.revisions[0];
        UKObjectsEqual([serverChild1.revision.parentRevision parentRevision].UUID,
                       clientMessage1Rev0.parentRevisionUUID);
        UKObjectsEqual(serverChild1.revision.parentRevision.UUID, clientMessage1Rev0.revisionUUID);

        COSynchronizerRevision *clientMessage1Rev1 = clientMessage1.revisions[1];
        UKObjectsEqual(serverChild1.revision.parentRevision.UUID,
                       clientMessage1Rev1.parentRevisionUUID);
        UKObjectsEqual(serverChild1.revision.UUID, clientMessage1Rev1.revisionUUID);
    }

    // Deliver the response to the client
    [transport deliverMessagesToClient];

    // Should not send anything more to server
    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);

    UKIntsEqual(2, [[clientBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [clientBranch.rootObject valueForKeyPath: @"contents.UUID"]);
}

- (void)testLocalClientCommitsAfterPushingToServer
{
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];

    UKIntsEqual(1, self.serverMessages.count);
    UKObjectKindOf(self.serverMessages[0], COSynchronizerPushedRevisionsFromClientMessage);

    UKIntsEqual(1, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerPushedRevisionsToClientMessage);

    // Server should merge in client's changes, and send a push response back to the client
    [transport deliverMessagesToServer];

    UKIntsEqual(0, self.serverMessages.count);

    UKIntsEqual(2, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0],
                   COSynchronizerPushedRevisionsToClientMessage); /* Will be ignored by client */
    UKObjectKindOf(self.clientMessages[1], COSynchronizerResponseToClientForSentRevisionsMessage);

    UKIntsEqual(2, [[serverBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [serverBranch.rootObject valueForKeyPath: @"contents.UUID"]);

    // Before the merged changes arrives at the client, make another commit on the client

    [clientBranch.rootObject setLabel: @"more changes"];
    [clientPersistentRoot commitWithMetadata: self.clientRevisionMetadataForTest];
    UKObjectsEqual(self.clientRevisionMetadataForTest,
                   clientPersistentRoot.currentRevision.metadata);

    // This should not produce any more messages

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(2, self.clientMessages.count);

    // Deliver the merge response to the client
    [transport deliverMessagesToClient];

    UKObjectsEqual(@"more changes", [clientBranch.rootObject label]);
    UKObjectsEqual(self.clientRevisionMetadataForTest,
                   clientPersistentRoot.currentRevision.metadata);

    // The client should push back the @"more changes" change to the server

    UKIntsEqual(1, self.serverMessages.count);
    UKObjectKindOf(self.serverMessages[0], COSynchronizerPushedRevisionsFromClientMessage);
    UKIntsEqual(0, self.clientMessages.count);

    [transport deliverMessagesToServer];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(1, self.clientMessages.count);
    UKObjectKindOf(self.clientMessages[0], COSynchronizerResponseToClientForSentRevisionsMessage);

    UKObjectsEqual(@"more changes", [serverBranch.rootObject label]);

    [transport deliverMessagesToClient];

    // Should not send anything more
    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);
}

// FIXME: For some reason, this test case causes a COSQLiteStore to be leaked.
// I think it's something to do with the exception thrown during -commit.
- (void)testBasicServerRevert
{
    [serverBranch.rootObject setLabel: @"revertThis"];
    [serverPersistentRoot commit];

    [transport deliverMessagesToClient];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);
    UKObjectsEqual(@"revertThis", [clientBranch.rootObject label]);

    UKRaisesException(serverBranch.currentRevision = serverBranch.currentRevision.parentRevision);
    [serverPersistentRoot commit];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);
}

// FIXME: This test case causes a COSQLiteStore to be leaked (see previous test too).
- (void)testBasicClientRevert
{
    [serverBranch.rootObject setLabel: @"revertThis"];
    [serverPersistentRoot commit];

    [transport deliverMessagesToClient];

    UKIntsEqual(0, self.serverMessages.count);
    UKIntsEqual(0, self.clientMessages.count);
    UKObjectsEqual(@"revertThis", [clientBranch.rootObject label]);

    UKRaisesException([clientBranch setCurrentRevision: clientBranch.currentRevision.parentRevision]);
    [clientPersistentRoot commit];

    // No more messages

    UKIntsEqual(0, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);
}

- (void)testMergeOverlappingAttributeAdditions
{
    /*
     server:
     
     "Hello"
     
     */

    COAttributedString *serverStr = [[COAttributedString alloc] initWithObjectGraphContext: serverBranch.objectGraphContext];
    [(UnorderedGroupNoOpposite *)serverBranch.rootObject setContents: S(serverStr)];
    [self appendString: @"Hello" htmlCode: nil toAttributedString: serverStr];
    [serverPersistentRoot commit];

    [transport deliverMessagesToClient];

    /*
     client:
     
     "Hello"
      ^^^^
     bold
     
     */

    COAttributedString *clientStr = [((UnorderedGroupNoOpposite *)clientBranch.rootObject).contents anyObject];
    COAttributedStringWrapper *clientWrapper = [[COAttributedStringWrapper alloc] initWithBacking: clientStr];
    [self setFontTraits: NSFontBoldTrait inRange: NSMakeRange(0, 4) inTextStorage: clientWrapper];
    [clientPersistentRoot commit];

    /*
     server:
     
     "Hello"
        ^^^
     underline
     
     */

    COAttributedStringWrapper *serverWrapper = [[COAttributedStringWrapper alloc] initWithBacking: serverStr];
    [serverWrapper setAttributes: @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)}
                           range: NSMakeRange(2, 3)];
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

    UKObjectsEqual(@"Hello", serverWrapper.string);
    [self checkFontHasTraits: NSFontBoldTrait
   withLongestEffectiveRange: NSMakeRange(0, 4)
          inAttributedString: serverWrapper];
    [self  checkAttribute: NSUnderlineStyleAttributeName
                 hasValue: @(NSUnderlineStyleSingle)
withLongestEffectiveRange: NSMakeRange(2, 3)
       inAttributedString: serverWrapper];
}

#pragma mark - COAttributedString

- (void)testClientAttributedStringEdits
{
    COAttributedString *serverStr = [[COAttributedString alloc] initWithObjectGraphContext: serverBranch.objectGraphContext];
    COAttributedStringWrapper *serverWrapper = [[COAttributedStringWrapper alloc] initWithBacking: serverStr];
    [(UnorderedGroupNoOpposite *)serverBranch.rootObject setContents: S(serverStr)];
    [serverPersistentRoot commit];

    [transport deliverMessagesToClient];

    COAttributedString *clientStr = [((UnorderedGroupNoOpposite *)clientBranch.rootObject).contents anyObject];
    COAttributedStringWrapper *clientWrapper = [[COAttributedStringWrapper alloc] initWithBacking: clientStr];
    [clientWrapper replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
    [clientPersistentRoot commit];

    [clientWrapper replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
    [clientPersistentRoot commit];

    [clientWrapper replaceCharactersInRange: NSMakeRange(2, 0) withString: @"c"];
    [clientPersistentRoot commit];

    // deliver 'a' to server. The client will only have sent one message, since
    // it waits for confirmation before sending more.
    [transport deliverMessagesToServer];
    UKObjectsEqual(@"a", serverWrapper.string);

    // confirmation that 'a' was received -> client
    // Make sure that the client doesn't do any unnecessary rebasing
    ETUUID *clientABCRevision = clientBranch.currentRevision.UUID;
    [transport deliverMessagesToClient];
    UKObjectsEqual(clientABCRevision, clientBranch.currentRevision.UUID);
    UKObjectsEqual(@"abc", clientWrapper.string);

    // 'ab' and 'abc' commits -> server
    [transport deliverMessagesToServer];
    UKObjectsEqual(@"abc", serverWrapper.string);

    // confirmation that all 3 commits were received
    [transport deliverMessagesToClient];
    UKObjectsEqual(@"abc", clientWrapper.string);

    UKIntsEqual(0, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);
}

- (NSString *)stringForRevision: (CORevision *)aRevision persistentRoot: (COPersistentRoot *)proot
{
    COObjectGraphContext *graph = [proot objectGraphContextForPreviewingRevision: aRevision];
    COAttributedStringWrapper *wrapper = [[COAttributedStringWrapper alloc] initWithBacking: [((UnorderedGroupNoOpposite *)graph.rootObject).contents anyObject]];
    return wrapper.string;
}

/**
 * For this to pass, the client and server need to use a consistent
 * conflict resolution pattern. i.e., they must both favour the client's changes,
 * or both favour the server's changes.
 *
 * It's an interesting case because the merge is split into two phases,
 * in one the first character of the client's text ("a") is merged, and later
 * the next two are ("bc").
 */
- (void)testConflictingAttributedStringInserts
{
    COAttributedString *serverStr = [[COAttributedString alloc] initWithObjectGraphContext: serverBranch.objectGraphContext];
    COAttributedStringWrapper *serverWrapper = [[COAttributedStringWrapper alloc] initWithBacking: serverStr];
    [(UnorderedGroupNoOpposite *)serverBranch.rootObject setContents: S(serverStr)];
    [serverPersistentRoot commit];

    [transport deliverMessagesToClient];

    // 3 commits on client

    COAttributedString *clientStr = [((UnorderedGroupNoOpposite *)clientBranch.rootObject).contents anyObject];
    COAttributedStringWrapper *clientWrapper = [[COAttributedStringWrapper alloc] initWithBacking: clientStr];
    [clientWrapper replaceCharactersInRange: NSMakeRange(0, 0) withString: @"a"];
    [clientPersistentRoot commit];

    [clientWrapper replaceCharactersInRange: NSMakeRange(1, 0) withString: @"b"];
    [clientPersistentRoot commit];

    [clientWrapper replaceCharactersInRange: NSMakeRange(2, 0) withString: @"c"];
    [clientPersistentRoot commit];
    CORevision *clientABCrev = clientPersistentRoot.currentRevision;


    // 3 commits on server

    [serverWrapper replaceCharactersInRange: NSMakeRange(0, 0) withString: @"d"];
    [serverPersistentRoot commit];

    [serverWrapper replaceCharactersInRange: NSMakeRange(1, 0) withString: @"e"];
    [serverPersistentRoot commit];

    [serverWrapper replaceCharactersInRange: NSMakeRange(2, 0) withString: @"f"];
    [serverPersistentRoot commit];


    // deliver 'a' to server. The client will only have sent one message, since
    // it waits for confirmation before sending more.
    [transport deliverMessagesToServer];
    UKTrue([@"adef" isEqualToString: serverWrapper.string]
           || [@"defa" isEqualToString: serverWrapper.string]);


    // The client does the critical merge

    /**
     * Messages 1-3 are pushes from the server for the server's "a", "ab", "abc"
     * commits. The client ignores these because it is waiting for a response to its push.
     * Message 4 is the response to the client's push
     */
    UKIntsEqual(4, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);

    /**
     * The client gets a revision with "defa" or "adef", and then rebases 2
     * commits ("ab", "abc") on top of that to get ("defa", "defab", "defabc")
     * or ("adef", "abdef", "abcdef")
     */
    [transport deliverMessagesToClient];

    UKTrue([@"abcdef" isEqualToString: clientWrapper.string]
           || [@"defabc" isEqualToString: clientWrapper.string]);

    // Check the new client history graph

    CORevision *client_DEFABC_Revision = clientPersistentRoot.currentRevision;
    CORevision *client_DEFAB_Revision = client_DEFABC_Revision.parentRevision;
    CORevision *client_DEFA_Revision = client_DEFAB_Revision.parentRevision;
    CORevision *client_DEF_Revision = client_DEFA_Revision.parentRevision;
    CORevision *client_DE_Revision = client_DEF_Revision.parentRevision;
    CORevision *client_D_Revision = client_DE_Revision.parentRevision;

    NSString *client_DEFABC_String = [self stringForRevision: client_DEFABC_Revision
                                              persistentRoot: clientPersistentRoot];
    NSString *client_DEFAB_String = [self stringForRevision: client_DEFAB_Revision
                                             persistentRoot: clientPersistentRoot];
    NSString *client_DEFA_String = [self stringForRevision: client_DEFA_Revision
                                            persistentRoot: clientPersistentRoot];
    NSString *client_DEF_String = [self stringForRevision: client_DEF_Revision
                                           persistentRoot: clientPersistentRoot];
    NSString *client_DE_String = [self stringForRevision: client_DE_Revision
                                          persistentRoot: clientPersistentRoot];
    NSString *client_D_String = [self stringForRevision: client_D_Revision
                                         persistentRoot: clientPersistentRoot];

    UKTrue([@"abcdef" isEqualToString: client_DEFABC_String]
           || [@"defabc" isEqualToString: client_DEFABC_String]);
    UKTrue([@"abdef" isEqualToString: client_DEFAB_String]
           || [@"defab" isEqualToString: client_DEFAB_String]);
    UKTrue([@"adef" isEqualToString: client_DEFA_String]
           || [@"defa" isEqualToString: client_DEFA_String]);
    UKTrue([@"def" isEqualToString: client_DEF_String]);
    UKTrue([@"de" isEqualToString: client_DE_String]);
    UKTrue([@"d" isEqualToString: client_D_String]);

    // Send confirmation to server
    [transport deliverMessagesToServer];
    UKTrue([@"abcdef" isEqualToString: serverWrapper.string]
           || [@"defabc" isEqualToString: serverWrapper.string]);

    // Send confirmation back to client
    [transport deliverMessagesToClient];
    UKTrue([@"abcdef" isEqualToString: clientWrapper.string]
           || [@"defabc" isEqualToString: clientWrapper.string]);

    UKIntsEqual(0, self.clientMessages.count);
    UKIntsEqual(0, self.serverMessages.count);
}

@end

