/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import <CoreObject/COEditingContext+Private.h>
#import <CoreObject/COBranch+Private.h>
#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

#import "COSynchronizerUtils.h"

#import "COStoreTransaction.h"

@implementation COSynchronizerClient

@synthesize delegate = _delegate;
@synthesize branch = _branch;
@synthesize clientID = _clientID;

- (COPersistentRoot *)persistentRoot
{
    return _branch.persistentRoot;
}

- (ETUUID *)lastRevisionUUIDInTransitToServer
{
    return _lastRevisionUUIDInTransitToServer;
}

- (ETUUID *)lastRevisionUUIDFromServer
{
    return _lastRevisionUUIDFromServer;
}

- (instancetype)initWithClientID: (NSString *)clientID
                  editingContext: (COEditingContext *)ctx
{
    NILARG_EXCEPTION_TEST(clientID);
    NILARG_EXCEPTION_TEST(ctx);
    SUPERINIT;

    _ctx = ctx;
    _clientID = clientID;

    return self;
}

- (instancetype)init
{
    return [self initWithClientID: nil editingContext: nil];
}

- (void)handleSetupMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
{
    if (_branch != nil)
    {
        NSLog(@"COSynchronizerClient already set up");
        return;
    }

    COStoreTransaction *txn = [[COStoreTransaction alloc] init];

    // 1. Do we have the persistent root?
    __block COPersistentRoot *persistentRoot = [_ctx persistentRootForUUID: message.persistentRootUUID];
    if (persistentRoot == nil)
    {
        [txn createPersistentRootWithUUID: message.persistentRootUUID persistentRootForCopy: nil];
        [txn setMetadata: message.persistentRootMetadata
       forPersistentRoot: message.persistentRootUUID];
    }

    // 2. Do we have the branch?
    if (persistentRoot == nil
        || [persistentRoot branchForUUID: message.branchUUID] == nil)
    {
        [txn createBranchWithUUID: message.branchUUID
                     parentBranch: nil
                  initialRevision: message.currentRevision.revisionUUID
                forPersistentRoot: message.persistentRootUUID];

        [txn setMetadata: message.branchMetadata
               forBranch: message.branchUUID
        ofPersistentRoot: message.persistentRootUUID];

        [txn setCurrentBranch: message.branchUUID
            forPersistentRoot: message.persistentRootUUID];
    }

    // 3. Do we have the revision?
    if ([_ctx.store revisionInfoForRevisionUUID: message.currentRevision.revisionUUID
                             persistentRootUUID: message.persistentRootUUID] == nil)
    {
        [message.currentRevision writeToTransaction: txn
                                 persistentRootUUID: message.persistentRootUUID
                                         branchUUID: message.branchUUID
                                    isFirstRevision: YES];
    }

    ETAssert([_ctx.store commitStoreTransaction: txn]);

    persistentRoot = [_ctx persistentRootForUUID: message.persistentRootUUID];
    ETAssert(persistentRoot != nil);
    _branch = [persistentRoot branchForUUID: message.branchUUID];

    if (_branch.hasChanges)
    {
        [NSException raise: NSGenericException
                    format: @"-[%@ %@] called but the branch has uncommitted changes. You should ensure all changes are committed before feeding the synchronizer a message.",
                            NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

    _branch.supportsRevert = NO;
    ETAssert(_branch != nil);
    _lastRevisionUUIDFromServer = message.currentRevision.revisionUUID;

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(persistentRootDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: persistentRoot];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)persistentRootDidChange: (NSNotification *)notif
{
    [self sendPushToServer];
}

- (void)handleRevisionsFromServer: (NSArray *)revs
{
    if ([[revs.lastObject revisionUUID] isEqual: self.branch.currentRevision.UUID])
    {
        // Bail out early without doing anything in the trivial case when there are no further changes
        // since we last sent something to the server.. this prevents the TestSynchronizerImmediateDelivery tests from failing.

        // TODO: It's kind of ugly that in the simple case, when a client commits something, sends it to the server,
        // the server replies back with the full content that the client sent (even though it knows it's unnecessary
        // to send that.) We still need to send the receipts though.

        _lastRevisionUUIDFromServer = [revs.lastObject revisionUUID];
        _lastRevisionUUIDInTransitToServer = nil;
        return;
    }

    ETUUID *lastServerRevUUID = [self lastRevisionUUIDFromServer];

    NSUInteger i = [revs indexOfObjectPassingTest: ^(id obj, NSUInteger idx, BOOL *stop)
    {
        COSynchronizerRevision *revision = obj;
        return [revision.parentRevisionUUID isEqual: lastServerRevUUID];
    }];

    if (i == NSNotFound)
    {
        NSLog(@"COSynchronizerClient: Ignoring push from server, it seems to be an old message that arrived late");

        // FIXME: write unit test for this case:
        //
        // - add outline item 1 on server
        // - Rename "outline item 1" to "foo" on server, leave field editor open (so the change isn't sent to the client)
        // - add outline item 2 on client
        // - end field editor on server
        //
        // The server processses the "add outline item 2 on client", which is waiting in a buffer.
        // Then server sends out the 'Rename "outline item 1" to "foo"' revision (which the client should ignore)
        // and server also sends the merged revision, which the client should accept.
        //
        // If the messages arrive out of order, so the merged (good) revision arrives at the client before the stale 'Rename "outline item 1" to "foo"' revision,
        // we get to this case.

        return;
    }

    _lastRevisionUUIDFromServer = [revs.lastObject revisionUUID];

    NSArray *revsToUse = [revs subarrayWithRange: NSMakeRange(i, revs.count - i)];


    // Apply the revisions

    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    for (COSynchronizerRevision *rev in revsToUse)
    {
        CORevision *existingRevisions = [self.persistentRoot.editingContext revisionForRevisionUUID: rev.revisionUUID
                                                                                 persistentRootUUID: self.persistentRoot.UUID];

        if (nil == existingRevisions)
        {
            [rev writeToTransaction: txn
                 persistentRootUUID: self.persistentRoot.UUID
                         branchUUID: self.branch.UUID
                    isFirstRevision: NO];
        }
    }
    // TODO: Ideally we'd just do one store commit, instead of two,
    // but the +rebaseRevision method below requires these revisions to be committed already.
    ETAssert([self.persistentRoot.store commitStoreTransaction: txn]);

    // Rebase [self.branch currentRevision] onto the new revisions

    const BOOL isCurrentRevDescendentOfServerRev =
        [_ctx  isRevision: [revs.lastObject revisionUUID]
equalToOrParentOfRevision: self.branch.currentRevision.UUID
           persistentRoot: self.persistentRoot.UUID];

    if (_lastRevisionUUIDInTransitToServer != nil
        && ![self.branch.currentRevision.UUID isEqual: _lastRevisionUUIDInTransitToServer]
        && !isCurrentRevDescendentOfServerRev)
    {
        txn = [[COStoreTransaction alloc] init];

        // N.B. The reason _lastRevisionUUIDInTransitToServer is the common ancestor for the rebasing is a bit subtle.
        //
        // It is the revision we sent to the server earlier, and we are currently
        // processing the response to sending that revision, so we know that revsToUse.lastObject
        // has the changes in _lastRevisionUUIDInTransitToServer merged in to it (although there is
        // no link showing that in our history graph, since the merge was done on the server).
        //
        // _lastRevisionUUIDInTransitToServer is also a parent of [self.branch currentRevision], so it is exactly the revision
        // we want to use as the common ancestor for rebasing.

        NSArray *rebasedRevs = [COSynchronizerUtils rebaseRevision: self.branch.currentRevision.UUID
                                                      ontoRevision: [revsToUse.lastObject revisionUUID]
                                                    commonAncestor: _lastRevisionUUIDInTransitToServer
                                                persistentRootUUID: self.persistentRoot.UUID
                                                        branchUUID: self.branch.UUID
                                                             store: self.persistentRoot.store
                                                       transaction: txn
                                                    editingContext: self.persistentRoot.editingContext
                                        modelDescriptionRepository: self.persistentRoot.editingContext.modelDescriptionRepository];
        ETAssert([self.persistentRoot.store commitStoreTransaction: txn]);

        [_branch setCurrentRevisionSkipSupportsRevertCheck: [self.persistentRoot.editingContext revisionForRevisionUUID: rebasedRevs.lastObject
                                                                                                     persistentRootUUID: self.persistentRoot.UUID]];
    }
    else if (!isCurrentRevDescendentOfServerRev)
    {
        // Fast-forward

        [_branch setCurrentRevisionSkipSupportsRevertCheck: [self.persistentRoot.editingContext revisionForRevisionUUID: [revsToUse.lastObject revisionUUID]
                                                                                                     persistentRootUUID: self.persistentRoot.UUID]];
    }
    _lastRevisionUUIDInTransitToServer = nil;
    [self.persistentRoot commit];
}

- (void)handlePushMessage: (COSynchronizerPushedRevisionsToClientMessage *)aMessage
{
    if (_lastRevisionUUIDInTransitToServer != nil)
    {
        return;
    }

    if (_branch.hasChanges)
    {
        [NSException raise: NSGenericException
                    format: @"-[%@ %@] called but the branch has uncommitted changes. You should ensure all changes are committed before feeding the synchronizer a message.",
                            NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

    [self handleRevisionsFromServer: aMessage.revisions];
}

- (void)handleResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aMessage
{
    if (![aMessage.lastRevisionUUIDSentByClient isEqual: [self lastRevisionUUIDInTransitToServer]])
    {
        return;
    }

    if (_branch.hasChanges)
    {
        [NSException raise: NSGenericException
                    format: @"-[%@ %@] called but the branch has uncommitted changes. You should ensure all changes are committed before feeding the synchronizer a message.",
                            NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

    // Benchmarking:
    NSTimeInterval roundtrip = [[NSDate date] timeIntervalSinceDate: _lastRevisionUUIDInTransitToServerTimestamp];
    NSLog(@"===> Round-trip time: %.0f ms", roundtrip * 1000.0);

    [self handleRevisionsFromServer: aMessage.revisions];
}

- (void)sendPushToServer
{
    ETAssert([self lastRevisionUUIDFromServer] != nil);
    if ([self lastRevisionUUIDInTransitToServer] != nil)
    {
        return;
    }
    if ([self.branch.currentRevision.UUID isEqual: [self lastRevisionUUIDFromServer]])
    {
        NSLog(@"sendPushToServer bailing because there is nothing to push");
        return;
    }

    NSMutableArray *revs = [[NSMutableArray alloc] init];

    NSArray *revUUIDs = [_ctx revisionUUIDsFromRevisionUUIDExclusive: [self lastRevisionUUIDFromServer]
                                             toRevisionUUIDInclusive: self.branch.currentRevision.UUID
                                                      persistentRoot: self.persistentRoot.UUID];

    for (ETUUID *revUUID in revUUIDs)
    {
        COSynchronizerRevision *rev = [[COSynchronizerRevision alloc] initWithUUID: revUUID
                                                                    persistentRoot: self.persistentRoot.UUID
                                                                             store: self.persistentRoot.store
                                                        recordAsDeltaAgainstParent: YES];
        [revs addObject: rev];
    }

    ETAssert(![revs isEmpty]);
    ETAssert(_lastRevisionUUIDInTransitToServer == nil);
    _lastRevisionUUIDInTransitToServer = self.branch.currentRevision.UUID;
    // Benchmarking:
    _lastRevisionUUIDInTransitToServerTimestamp = [NSDate date];

    COSynchronizerPushedRevisionsFromClientMessage *message = [[COSynchronizerPushedRevisionsFromClientMessage alloc] init];
    message.clientID = self.clientID;
    message.revisions = revs;
    message.lastRevisionUUIDSentByServer = [self lastRevisionUUIDFromServer];
    [self.delegate sendPushToServer: message];
}

@end
