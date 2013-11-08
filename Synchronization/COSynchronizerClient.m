#import "COSynchronizerClient.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerAcknowledgementFromClientMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

#import "COSynchronizerUtils.h"

#import "COSQLiteStore.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerClient

@synthesize delegate = _delegate;
@synthesize branch = _branch;
@synthesize clientID = _clientID;

- (COPersistentRoot *)persistentRoot { return [_branch persistentRoot]; }

/**
 * If [self.branch currentRevision] has "from-server" metadata, returns nil
 * (we are not awaiting a response from the server.)
 *
 * Otherwise, returns [self.branch currentRevision] - which is the _last_
 * (possibly of a batch) of commits that were made locally, that are currently
 * in transit to the server.
 */
- (CORevision *) lastRevisionInTransitToServer
{
	CORevision *lastRevisionFromServer = [self lastRevisionFromServer];
	if ([lastRevisionFromServer isEqual: [_branch currentRevision]])
	{
		return nil;
	}
	
	return [_branch currentRevision];
}

/**
 * Returns the last revision on self.branch that has "from-server" metadata.
 * Always non-nil.
 */
- (CORevision *) lastRevisionFromServer
{
	CORevision *currentRevision = [_branch currentRevision];
	
	while (currentRevision != nil)
	{
		NSDictionary *metadata = [currentRevision metadata];
		
		if ([metadata[@"fromServer"] boolValue])
		{
			return currentRevision;
		}
		
		currentRevision = [currentRevision parentRevision];
	}

	NSAssert(NO, @"COSynchronizerClient should have at least one revision with "
				  "fromServer=YES");
	return nil;
}


- (id) initWithSetupMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
				   clientID: (NSString *)clientID
			 editingContext: (COEditingContext *)ctx
{
	SUPERINIT;
	
	_ctx = ctx;
	
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	
	// 1. Do we have the persistent root?
	__block COPersistentRoot *persistentRoot = [ctx persistentRootForUUID: message.persistentRootUUID];
    if (persistentRoot == nil)
    {
		[txn createPersistentRootWithUUID: message.persistentRootUUID persistentRootForCopy: nil];
    }
	
	// 2. Do we have the branch?
	if (persistentRoot == nil
		|| [persistentRoot branchForUUID: message.branchUUID] == nil)
	{
		[txn createBranchWithUUID: message.branchUUID
					 parentBranch: nil
				  initialRevision: message.currentRevision.revisionUUID
				forPersistentRoot: message.persistentRootUUID];
	}
	
	// 3. Do we have the revision?
	if ([[ctx store] revisionInfoForRevisionUUID: message.currentRevision.revisionUUID
							  persistentRootUUID: message.persistentRootUUID] == nil)
	{
		[message.currentRevision writeToTransaction: txn
								 persistentRootUUID: message.persistentRootUUID
										 branchUUID: message.branchUUID];
	}
	
	[[_ctx store] commitStoreTransaction: txn];

	dispatch_async(dispatch_get_main_queue(), ^(){
		persistentRoot = [_ctx persistentRootForUUID: message.persistentRootUUID];
		ETAssert(persistentRoot != nil);
		_branch = [persistentRoot branchForUUID: message.branchUUID];
		ETAssert(_branch != nil);
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(persistentRootDidChange:)
													 name: COPersistentRootDidChangeNotification
												   object: persistentRoot];
	});
	
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (BOOL) isAwaitingResponse
{
	return [self lastRevisionInTransitToServer] != nil;
}

- (void) persistentRootDidChange: (NSNotification *)notif
{
	if (![self isAwaitingResponse])
	{
		[self sendPushToServer];
	}
}

- (void) handleRevisionsFromServer: (NSArray *)revs
{
	ETUUID *currentRevUUID = [[self lastRevisionFromServer] UUID];
	
	NSUInteger i = [revs indexOfObjectPassingTest: ^(id obj, NSUInteger idx, BOOL *stop)
					{
						COSynchronizerRevision *revision = obj;
						return [revision.parentRevisionUUID isEqual: currentRevUUID];
					}];
	
	ETAssert(i != NSNotFound);
	
	NSArray *revsToUse = [revs subarrayWithRange: NSMakeRange(i, [revs count] - i)];
	
	
	// Apply the revisions
	
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
	for (COSynchronizerRevision *rev in revsToUse)
	{
		[rev writeToTransaction: txn
			 persistentRootUUID: self.persistentRoot.UUID
					 branchUUID: self.branch.UUID];
	}
	// TODO: Ideally we'd just do one store commit, instead of two,
	// but the +rebaseRevision method below requires these revisions to be committed already.
	ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);
	
	// Rebase [self.branch currentRevision] onto the new revisions
	
	txn = [[COStoreTransaction alloc] init];
	NSArray *rebasedRevs = [COSynchronizerUtils rebaseRevision: [[self.branch currentRevision] UUID]
												  ontoRevision: [(COSynchronizerRevision *)[revsToUse lastObject] revisionUUID]
											persistentRootUUID: self.persistentRoot.UUID
													branchUUID: self.branch.UUID
														 store: [self.persistentRoot store]
												   transaction: txn];
	ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);

	[_branch setCurrentRevision: [rebasedRevs lastObject]];
	
	// Send receipt
	
	[self sendReceiptToServer];
	
	// Only does anything if there are unpushed revisions.
	// Note this is only possible if we are called from -handleResponseMessage:.
	
	[self sendPushToServer];
}

- (void) handlePushMessage: (COSynchronizerPushedRevisionsToClientMessage *)aMessage
{
	[self handleRevisionsFromServer: aMessage.revisions];
}

- (void) handleResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aMessage
{
	if (![aMessage.lastRevisionUUIDSentByClient isEqual: [[self lastRevisionInTransitToServer] UUID]])
	{
		return;
	}
	
	[self handleRevisionsFromServer: aMessage.revisions];
}

- (void) sendReceiptToServer
{
	COSynchronizerAcknowledgementFromClientMessage *message = [[COSynchronizerAcknowledgementFromClientMessage alloc] init];
	message.clientID = self.clientID;
	message.lastRevisionUUIDSentByServer = [[self lastRevisionFromServer] UUID];
	[self.delegate sendReceiptToServer: message];
}

- (void) sendPushToServer
{
	NSMutableArray *revs = [[NSMutableArray alloc] init];
	
	NSArray *revUUIDs = [COLeastCommonAncestor revisionUUIDsFromRevisionUUIDExclusive: [[self lastRevisionFromServer] UUID]
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
	
	COSynchronizerPushedRevisionsFromClientMessage *message = [[COSynchronizerPushedRevisionsFromClientMessage alloc] init];
	message.clientID = self.clientID;
	message.revisions = revs;
	[self.delegate sendPushToServer: message];
}

@end
