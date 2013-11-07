#import "COSynchronizerClient.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerAcknowledgementFromClientMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

@implementation COSynchronizerClient

@synthesize delegate = _delegate;


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
	return nil;
}

/**
 * Returns the last revision on self.branch that has "from-server" metadata.
 * Always non-nil.
 */
- (CORevision *) lastRevisionFromServer
{
	return nil;
}


- (id) initWithSetupMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
{
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(persistentRootDidChange:)
												 name: COPersistentRootDidChangeNotification
											   object: [_branch persistentRoot]];

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
		
	}
}

- (void) handleMessage: (NSDictionary *)aPropertyList
{
	if ([self isAwaitingResponse])
	{
//		if (![aPropertyList[@"revisionSentFromClient"] isEqual: [[lastRevisionInTransitToServer UUID] stringValue]])
//		{
//			return;
//		}
				
		[self handleResponseForSentRevisions];
	}
	else
	{
		[self handlePushedRevisionsFromServer];
	}
}

- (void) handlePushMessage: (COSynchronizerPushedRevisionsToClientMessage *)aMessage
{
	
}
- (void) handleResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aMessage
{
	
}


/**
 * Server pushed us some revisions out of the blue.
 */
- (void) handlePushedRevisionsFromServer
{
	
}

- (void) handleResponseForSentRevisions
{
	
	// Add the received revisions to our store.
	
	/* The server can send us an ordered array.
	 
	 It is guaranteed that there will be a chain starting at revisionInTransitToServer
	 containing one or more revisions.
	 
	 It is possible that first N revisions sent by the server are ones
	 we have already received, this is fine.
	 
	 */
	
	
	
//	if [branch currentRevision] != revisionInTransitToServer,
//	{
//		// rebase the changes after [branch currentRevision] onto the last revision
//		// sent from the server.
//		
//	}
//	else
//	{
//		// send receipt
//	}
//	lastRevisionInTransitToServer = nil;
	
	

}

@end
