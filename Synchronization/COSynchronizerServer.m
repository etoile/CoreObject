#import <CoreObject/CoreObject.h>
#import "CORevisionCache.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

#import "COSynchronizerUtils.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerServer

@synthesize delegate, branch = branch;

- (COPersistentRoot *)persistentRoot { return [branch persistentRoot]; }

- (id) initWithBranch: (COBranch *)aBranch;
{
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

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) persistentRootDidChange: (NSNotification *)notif
{
	for (NSString *clientID in [self clientIDs])
	{
		[self sendPushToClient: clientID];
	}
}

- (void) handleRevisions: (NSArray *)revs fromClient: (NSString *)clientID
{
	// TODO: Ideally we wouldn't even commit these revisions before rebasing them
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	for (COSynchronizerRevision *rev in revs)
	{
		[rev writeToTransaction: txn
			 persistentRootUUID: self.persistentRoot.UUID
					 branchUUID: self.branch.UUID];
	}
	ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);
	
	if (![COLeastCommonAncestor isRevision: [[self.branch currentRevision] UUID]
				 equalToOrParentOfRevision: [(COSynchronizerRevision *)[revs lastObject] revisionUUID]
							persistentRoot: self.persistentRoot.UUID
									 store: [self.persistentRoot store]])
	{
		// Rebase revs onto the current revisions
		
		txn = [[COStoreTransaction alloc] init];
		NSArray *rebasedRevs = [COSynchronizerUtils rebaseRevision: [(COSynchronizerRevision *)[revs lastObject] revisionUUID]
													  ontoRevision: [[self.branch currentRevision] UUID]
												persistentRootUUID: self.persistentRoot.UUID
														branchUUID: self.branch.UUID
															 store: [self.persistentRoot store]
													   transaction: txn];
		ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);
		
		[branch setCurrentRevision: [CORevisionCache revisionForRevisionUUID: [rebasedRevs lastObject]
														  persistentRootUUID: self.persistentRoot.UUID
																   storeUUID: [[self.persistentRoot store] UUID]]];
	}
	else
	{
		// Fast-forward
		
		[branch setCurrentRevision: [CORevisionCache revisionForRevisionUUID: [(COSynchronizerRevision *)[revs lastObject] revisionUUID]
														   persistentRootUUID: self.persistentRoot.UUID
																	storeUUID: [[self.persistentRoot store] UUID]]];
	}

	// Set the following ivars so -sendPushToClient: sends a response message
	// instead of a regular push message.

	ETAssert(clientID != nil);
	currentlyHandlingLastSentRevision = [(COSynchronizerRevision *)[revs lastObject] revisionUUID];
	currentlyRespondingToClient = clientID;
	
	// Will cause a call to -[self persistentRootDidChange:]
	[self.persistentRoot commit];
}

- (NSArray *)clientIDs
{
	return [lastSentRevisionForClientID allKeys];
}

- (void) addClientID: (NSString *)clientID
{
	if ([lastSentRevisionForClientID valueForKey: clientID] != nil)
	{
		NSLog(@"Already have client %@", clientID);
		return;
	}
	
	[self sendPersistentRootInfoMessageToClient: clientID];
}

- (void) removeClientID: (NSString *)clientID
{
	[lastSentRevisionForClientID removeObjectForKey: clientID];
}

- (void) handlePushedRevisionsFromClient: (COSynchronizerPushedRevisionsFromClientMessage *)aMessage
{
	ETAssert(aMessage.lastRevisionUUIDSentByServer != nil);
	lastSentRevisionForClientID[aMessage.clientID] = aMessage.lastRevisionUUIDSentByServer;
	[self handleRevisions: aMessage.revisions fromClient: aMessage.clientID];
}

- (void) sendPushToClient: (NSString *)clientID
{
	ETUUID *lastConfirmedForClient = lastSentRevisionForClientID[clientID];
	if ([lastConfirmedForClient isEqual: [[branch currentRevision] UUID]])
	{
		return;
	}
	lastSentRevisionForClientID[clientID] = [[branch currentRevision] UUID];
	
	NSMutableArray *revs = [[NSMutableArray alloc] init];
	
	NSArray *revUUIDs = [COLeastCommonAncestor revisionUUIDsFromRevisionUUIDExclusive: lastConfirmedForClient
															  toRevisionUUIDInclusive: [[self.branch currentRevision] UUID]
																	   persistentRoot: self.persistentRoot.UUID
																				store: self.persistentRoot.store];
	
	if (revUUIDs == nil)
	{
		[NSException raise: NSGenericException
					format: @"It appears the branch %@ being tracked by COSynchronizerServer was reverted", self.branch];
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
	
	if (currentlyHandlingLastSentRevision != nil)
	{
		ETAssert(currentlyRespondingToClient != nil);
		
		COSynchronizerResponseToClientForSentRevisionsMessage * message = [[COSynchronizerResponseToClientForSentRevisionsMessage alloc] init];
		message.revisions = revs;
		message.lastRevisionUUIDSentByClient = currentlyHandlingLastSentRevision;
		
		[self.delegate sendResponseMessage: message toClient: currentlyRespondingToClient];
		
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

- (void) sendPersistentRootInfoMessageToClient: (NSString *)aClient
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
