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

@implementation COSynchronizerServer

@synthesize delegate, branch = branch;

- (COPersistentRoot *)persistentRoot
{
    return branch.persistentRoot;
}

- (instancetype)initWithBranch: (COBranch *)aBranch
{
    NILARG_EXCEPTION_TEST(aBranch);
    SUPERINIT;
    branch = aBranch;
    branch.supportsRevert = NO;
    lastSentRevisionForClientID = [NSMutableDictionary new];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(persistentRootDidChange:)
                                                 name: COPersistentRootDidChangeNotification
                                               object: self.persistentRoot];

    return self;
}

- (instancetype)init
{
    return [self initWithBranch: nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)persistentRootDidChange: (NSNotification *)notif
{
    if (self.persistentRoot == nil)
    {
        NSLog(@"%@ outlasted the persistent root is was bound to.", self);
        return;
    }

    for (NSString *clientID in self.clientIDs)
    {
        [self sendPushToClient: clientID];
    }
}

- (void)handleRevisions: (NSArray *)revs fromClient: (NSString *)clientID
{
    // TODO: Ideally we wouldn't even commit these revisions before rebasing them
    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    for (COSynchronizerRevision *rev in revs)
    {
        [rev writeToTransaction: txn
             persistentRootUUID: self.persistentRoot.UUID
                     branchUUID: self.branch.UUID
                isFirstRevision: NO];
    }
    ETAssert([self.persistentRoot.store commitStoreTransaction: txn]);

    if (!CORevisionUUIDEqualToOrParent(self.branch.currentRevision.UUID,
                                       [revs.lastObject revisionUUID],
                                       self.persistentRoot.UUID,
                                       branch.editingContext))
    {
        // Rebase revs onto the current revisions

        txn = [[COStoreTransaction alloc] init];

        ETUUID *source = [revs.lastObject revisionUUID];
        ETUUID *dest = self.branch.currentRevision.UUID;
        ETUUID *lca = COCommonAncestorRevisionUUIDs(source, 
                                                    dest,
                                                    self.persistentRoot.UUID,
                                                    self.persistentRoot.editingContext);

        NSArray *rebasedRevs = [COSynchronizerUtils rebaseRevision: source
                                                      ontoRevision: dest
                                                    commonAncestor: lca
                                                persistentRootUUID: self.persistentRoot.UUID
                                                        branchUUID: self.branch.UUID
                                                             store: self.persistentRoot.store
                                                       transaction: txn
                                                    editingContext: self.persistentRoot.editingContext
                                        modelDescriptionRepository: self.persistentRoot.editingContext.modelDescriptionRepository];
        ETAssert([self.persistentRoot.store commitStoreTransaction: txn]);

        [branch setCurrentRevisionSkipSupportsRevertCheck: [self.persistentRoot.editingContext revisionForRevisionUUID: rebasedRevs.lastObject
                                                                                                    persistentRootUUID: self.persistentRoot.UUID]];
    }
    else
    {
        // Fast-forward

        [branch setCurrentRevisionSkipSupportsRevertCheck: [self.persistentRoot.editingContext revisionForRevisionUUID: [revs.lastObject revisionUUID]
                                                                                                    persistentRootUUID: self.persistentRoot.UUID]];
    }

    // Set the following ivars so -sendPushToClient: sends a response message
    // instead of a regular push message.

    ETAssert(clientID != nil);
    currentlyHandlingLastSentRevision = [revs.lastObject revisionUUID];
    currentlyRespondingToClient = clientID;

    // Will cause a call to -[self persistentRootDidChange:]
    [self.persistentRoot commit];
}

- (NSArray *)clientIDs
{
    return lastSentRevisionForClientID.allKeys;
}

- (void)addClientID: (NSString *)clientID
{
    if ([lastSentRevisionForClientID valueForKey: clientID] != nil)
    {
        NSLog(@"Already have client %@", clientID);
        return;
    }

    [self sendPersistentRootInfoMessageToClient: clientID];
}

- (void)removeClientID: (NSString *)clientID
{
    [lastSentRevisionForClientID removeObjectForKey: clientID];
}

- (void)handlePushedRevisionsFromClient: (COSynchronizerPushedRevisionsFromClientMessage *)aMessage
{
    if (branch.hasChanges)
    {
        [NSException raise: NSGenericException
                    format: @"-[%@ %@] called but the branch has uncommitted changes. You should ensure all changes are committed before feeding the synchronizer a message.",
                            NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

    ETAssert(aMessage.lastRevisionUUIDSentByServer != nil);
    lastSentRevisionForClientID[aMessage.clientID] = aMessage.lastRevisionUUIDSentByServer;
    [self handleRevisions: aMessage.revisions fromClient: aMessage.clientID];
}

- (void)sendPushToClient: (NSString *)clientID
{
    ETUUID *lastConfirmedForClient = lastSentRevisionForClientID[clientID];
    if ([lastConfirmedForClient isEqual: branch.currentRevision.UUID])
    {
        return;
    }
    lastSentRevisionForClientID[clientID] = branch.currentRevision.UUID;

    NSMutableArray *revs = [[NSMutableArray alloc] init];

    ETAssert(branch.editingContext != nil);
    NSArray *revUUIDs = CORevisionsUUIDsFromExclusiveToInclusive(lastConfirmedForClient,
                                                                 self.branch.currentRevision.UUID,
                                                                 self.persistentRoot.UUID,
                                                                 branch.editingContext);

    if (revUUIDs == nil)
    {
        [NSException raise: NSGenericException
                    format: @"It appears the branch %@ being tracked by COSynchronizerServer was reverted",
                            self.branch];
    }

    for (ETUUID *revUUID in revUUIDs)
    {
        COSynchronizerRevision *rev = [[COSynchronizerRevision alloc] initWithUUID: revUUID
                                                                    persistentRoot: self.persistentRoot.UUID
                                                                             store: self.persistentRoot.store
                                                        recordAsDeltaAgainstParent: YES];
        [revs addObject: rev];
    }

    if ([revs isEmpty])
    {
        NSLog(@"sendPushToServer bailing because there is nothing to push");
        return;
    }

    if (currentlyHandlingLastSentRevision != nil
        && [currentlyRespondingToClient isEqualToString: clientID])
    {
        ETAssert(currentlyRespondingToClient != nil);

        COSynchronizerResponseToClientForSentRevisionsMessage *message = [[COSynchronizerResponseToClientForSentRevisionsMessage alloc] init];
        message.revisions = revs;
        message.lastRevisionUUIDSentByClient = currentlyHandlingLastSentRevision;

        [self.delegate sendResponseMessage: message toClient: clientID];

        currentlyHandlingLastSentRevision = nil;
        currentlyRespondingToClient = nil;
    }
    else
    {
        COSynchronizerPushedRevisionsToClientMessage *message = [[COSynchronizerPushedRevisionsToClientMessage alloc] init];
        message.revisions = revs;
        [self.delegate sendPushedRevisions: message toClients: @[clientID]];
    }
}

- (void)sendPersistentRootInfoMessageToClient: (NSString *)aClient
{
    COSynchronizerPersistentRootInfoToClientMessage *message = [[COSynchronizerPersistentRootInfoToClientMessage alloc] init];

    message.persistentRootUUID = self.persistentRoot.UUID;
    message.persistentRootMetadata = self.persistentRoot.metadata;
    message.branchUUID = self.branch.UUID;
    message.branchMetadata = self.branch.metadata;
    message.currentRevision = [[COSynchronizerRevision alloc] initWithUUID: self.branch.currentRevision.UUID
                                                            persistentRoot: self.persistentRoot.UUID
                                                                     store: self.persistentRoot.store
                                                recordAsDeltaAgainstParent: NO];

    lastSentRevisionForClientID[aClient] = self.branch.currentRevision.UUID;
    [self.delegate sendPersistentRootInfoMessage: message toClient: aClient];
}

@end
