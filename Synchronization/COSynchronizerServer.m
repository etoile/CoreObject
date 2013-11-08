#import "COSynchronizerServer.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerAcknowledgementFromClientMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

#import "COSynchronizerUtils.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerServer

@synthesize delegate, persistentRoot = persistentRoot, branch = branch;

- (id)init
{
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(persistentRootDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: persistentRoot];
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) persistentRootDidChange: (NSNotification *)notif
{
	for (NSString *clientID in [lastConfirmedRevisionForClientID allKeys])
	{
		[self sendPushToClient: clientID];
	}
}

- (void) handleRevisionsFromClient: (NSArray *)revs
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
	
	// Rebase revs onto the current revisions
	
	txn = [[COStoreTransaction alloc] init];
	NSArray *rebasedRevs = [COSynchronizerUtils rebaseRevision: [(COSynchronizerRevision *)[revs lastObject] revisionUUID]
												  ontoRevision: [[self.branch currentRevision] UUID]
											persistentRootUUID: self.persistentRoot.UUID
													branchUUID: self.branch.UUID
														 store: [self.persistentRoot store]
												   transaction: txn];
	ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);
	
	[branch setCurrentRevision: [rebasedRevs lastObject]];
	// Will cause a call to -[self persistentRootDidChange:]
	[self.persistentRoot commit];
}

- (void) addClientID: (NSString *)clientID
{
//	if ([lastConfirmedRevisionForClientID valueForKey: clientID] != nil)
//	{
//		NSLog(@"Already have client %@", clientID);
//		return;
//	}
//	
//	ETAssert([[branch nodes] containsObject: aRevision]);
//	
//	[lastConfirmedRevisionForClientID setObject: aRevision forKey: clientID];
}

- (void) removeClientID: (NSString *)clientID
{
	[lastConfirmedRevisionForClientID removeObjectForKey: clientID];
	[lastSentRevisionForClientID removeObjectForKey: clientID];
}

- (void) handlePushedRevisionsFromClient: (COSynchronizerPushedRevisionsFromClientMessage *)aMessage
{
	[self handleRevisionsFromClient: aMessage.revisions];
}

- (void) handleReceiptFromClient: (COSynchronizerAcknowledgementFromClientMessage *)aMessage
{
	// FIXME: Check if aMessage.lastRevisionUUIDSentByServer is older than lastConfirmedRevisionForClientID[aMessage.clientID]
	// (in case the messages got reordered)
	[lastConfirmedRevisionForClientID setObject: aMessage.lastRevisionUUIDSentByServer
										 forKey: aMessage.clientID];
}

- (void) sendPushToClient: (NSString *)clientID
{
	ETUUID *lastSentForClient = lastSentRevisionForClientID[clientID];
	if ([lastSentForClient isEqual: [[branch currentRevision] UUID]])
	{
		return;
	}
	
	NSMutableArray *revs = [[NSMutableArray alloc] init];
	
	NSArray *revUUIDs = [COLeastCommonAncestor revisionUUIDsFromRevisionUUIDExclusive: lastSentForClient
															  toRevisionUUIDInclusive: [[self.branch currentRevision] UUID]
																	   persistentRoot: self.persistentRoot.UUID
																				store: self.persistentRoot.store];
	
	for (ETUUID *revUUID in revUUIDs)
	{
		COSynchronizerRevision *rev = [[COSynchronizerRevision alloc] initWithUUID: revUUID
																	persistentRoot: self.persistentRoot.UUID
																			 store: self.persistentRoot.store];
		[revs addObject: rev];
	}
	
	if ([revs isEmpty])
	{
		NSLog(@"sendPushToServer bailing because there is nothing to push");
		return;
	}
	
	COSynchronizerPushedRevisionsToClientMessage *message = [[COSynchronizerPushedRevisionsToClientMessage alloc] init];
	message.revisions = revs;
	[self.delegate sendPushedRevisions: message toClients: @[clientID]];
}


- (void) sendResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aPropertyList
					toClient: (NSString *)aJID
{
	
}

- (void) sendPersistentRootInfoMessage: (COSynchronizerPersistentRootInfoToClientMessage *)aMessage
							  toClient: (NSString *)aClient
{
	
}

@end
