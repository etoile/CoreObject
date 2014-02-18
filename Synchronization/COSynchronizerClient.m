/*
    Copyright (C) 2013 Eric Wasylishen

    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <CoreObject/CoreObject.h>
#import <CoreObject/COEditingContext+Private.h>
#import "CORevisionCache.h"
#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

#import "COSynchronizerUtils.h"

#import "COSQLiteStore.h"
#import "COStoreTransaction.h"

@implementation COSynchronizerClient

@synthesize delegate = _delegate;
@synthesize branch = _branch;
@synthesize clientID = _clientID;

- (COPersistentRoot *)persistentRoot { return [_branch persistentRoot]; }

- (ETUUID *) lastRevisionUUIDInTransitToServer
{
	return _lastRevisionUUIDInTransitToServer;
}

- (ETUUID *) lastRevisionUUIDFromServer
{
	return _lastRevisionUUIDFromServer;
}

- (id) initWithClientID: (NSString *)clientID
		 editingContext: (COEditingContext *)ctx
{
	SUPERINIT;
	
	_ctx = ctx;
	_clientID = clientID;
	
	return self;
}


- (void) handleSetupMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
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
    }
	
	// 2. Do we have the branch?
	if (persistentRoot == nil
		|| [persistentRoot branchForUUID: message.branchUUID] == nil)
	{
		[txn createBranchWithUUID: message.branchUUID
					 parentBranch: nil
				  initialRevision: message.currentRevision.revisionUUID
				forPersistentRoot: message.persistentRootUUID];
		
		[txn setCurrentBranch: message.branchUUID
			forPersistentRoot: message.persistentRootUUID];
	}
	
	// 3. Do we have the revision?
	if ([[_ctx store] revisionInfoForRevisionUUID: message.currentRevision.revisionUUID
							  persistentRootUUID: message.persistentRootUUID] == nil)
	{
		[message.currentRevision writeToTransaction: txn
								 persistentRootUUID: message.persistentRootUUID
										 branchUUID: message.branchUUID];
	}
	
	ETAssert([[_ctx store] commitStoreTransaction: txn]);

	persistentRoot = [_ctx persistentRootForUUID: message.persistentRootUUID];
	ETAssert(persistentRoot != nil);
	_branch = [persistentRoot branchForUUID: message.branchUUID];
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

- (void) persistentRootDidChange: (NSNotification *)notif
{
	[self sendPushToServer];
}

- (void) handleRevisionsFromServer: (NSArray *)revs
{
	ETUUID *lastServerRevUUID = [self lastRevisionUUIDFromServer];
	_lastRevisionUUIDFromServer = [[revs lastObject] revisionUUID];
	
	NSUInteger i = [revs indexOfObjectPassingTest: ^(id obj, NSUInteger idx, BOOL *stop)
					{
						COSynchronizerRevision *revision = obj;
						return [revision.parentRevisionUUID isEqual: lastServerRevUUID];
					}];
	
	ETAssert(i != NSNotFound);
	
	NSArray *revsToUse = [revs subarrayWithRange: NSMakeRange(i, [revs count] - i)];
	
	
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
						 branchUUID: self.branch.UUID];
		}
	}
	// TODO: Ideally we'd just do one store commit, instead of two,
	// but the +rebaseRevision method below requires these revisions to be committed already.
	ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);
	
	// Rebase [self.branch currentRevision] onto the new revisions
	
	const BOOL isCurrentRevDescendentOfServerRev =
			[_ctx isRevision: [(COSynchronizerRevision *)[revs lastObject] revisionUUID]
   equalToOrParentOfRevision: [[self.branch currentRevision] UUID]
			  persistentRoot: self.persistentRoot.UUID];
	
	if (_lastRevisionUUIDInTransitToServer != nil
		&& ![[[self.branch currentRevision] UUID] isEqual: _lastRevisionUUIDInTransitToServer]
		&& !isCurrentRevDescendentOfServerRev)
	{
		txn = [[COStoreTransaction alloc] init];
		
		// N.B. The reason _lastRevisionUUIDInTransitToServer is the common ancestor for the rebasing is a bit subtle.
		//
		// It is the revision we sent to the server earlier, and we are currently
		// processing the response to sending that revision, so we know that [revsToUse lastObject]
		// has the changes in _lastRevisionUUIDInTransitToServer merged in to it (although there is
		// no link showing that in our history graph, since the merge was done on the server).
		//
		// _lastRevisionUUIDInTransitToServer is also a parent of [self.branch currentRevision], so it is exactly the revision
		// we want to use as the common ancestor for rebasing.
		
		NSArray *rebasedRevs = [COSynchronizerUtils rebaseRevision: [[self.branch currentRevision] UUID]
													  ontoRevision: [(COSynchronizerRevision *)[revsToUse lastObject] revisionUUID]
													commonAncestor: _lastRevisionUUIDInTransitToServer
												persistentRootUUID: self.persistentRoot.UUID
														branchUUID: self.branch.UUID
															 store: [self.persistentRoot store]
													   transaction: txn
													editingContext: self.persistentRoot.editingContext
										modelDescriptionRepository: self.persistentRoot.editingContext.modelDescriptionRepository];
		ETAssert([[self.persistentRoot store] commitStoreTransaction: txn]);

		[_branch setCurrentRevision: [self.persistentRoot.editingContext revisionForRevisionUUID: [rebasedRevs lastObject]
																			  persistentRootUUID: self.persistentRoot.UUID]];
	}
	else if (!isCurrentRevDescendentOfServerRev)
	{
		// Fast-forward
		
		[_branch setCurrentRevision: [self.persistentRoot.editingContext revisionForRevisionUUID: [(COSynchronizerRevision *)[revsToUse lastObject] revisionUUID]
																			  persistentRootUUID: self.persistentRoot.UUID]];
	}
	_lastRevisionUUIDInTransitToServer = nil;
	[self.persistentRoot commit];
}

- (void) handlePushMessage: (COSynchronizerPushedRevisionsToClientMessage *)aMessage
{
	if (_lastRevisionUUIDInTransitToServer != nil)
	{
		return;
	}
	
	[self handleRevisionsFromServer: aMessage.revisions];
}

- (void) handleResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aMessage
{
	if (![aMessage.lastRevisionUUIDSentByClient isEqual: [self lastRevisionUUIDInTransitToServer]])
	{
		return;
	}

	// Benchmarking:
	NSTimeInterval roundtrip = [[NSDate date] timeIntervalSinceDate: _lastRevisionUUIDInTransitToServerTimestamp];
	NSLog(@"===> Round-trip time: %.0f ms", roundtrip * 1000.0);
	
	[self handleRevisionsFromServer: aMessage.revisions];
}

- (void) sendPushToServer
{
	ETAssert([self lastRevisionUUIDFromServer] != nil);
	if ([self lastRevisionUUIDInTransitToServer] != nil)
	{
		return;
	}
	if ([[[self.branch currentRevision] UUID] isEqual: [self lastRevisionUUIDFromServer]])
	{
		NSLog(@"sendPushToServer bailing because there is nothing to push");
		return;
	}
	
	NSMutableArray *revs = [[NSMutableArray alloc] init];
	
	NSArray *revUUIDs = [_ctx revisionUUIDsFromRevisionUUIDExclusive: [self lastRevisionUUIDFromServer]
											 toRevisionUUIDInclusive: [[self.branch currentRevision] UUID]
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
	_lastRevisionUUIDInTransitToServer = [[self.branch currentRevision] UUID];
	// Benchmarking:
	_lastRevisionUUIDInTransitToServerTimestamp = [NSDate date];
	
	COSynchronizerPushedRevisionsFromClientMessage *message = [[COSynchronizerPushedRevisionsFromClientMessage alloc] init];
	message.clientID = self.clientID;
	message.revisions = revs;
	message.lastRevisionUUIDSentByServer = [self lastRevisionUUIDFromServer];
	[self.delegate sendPushToServer: message];
}

@end
