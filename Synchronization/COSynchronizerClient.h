#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>

@class COSynchronizerAcknowledgementFromClientMessage;
@class COSynchronizerPushedRevisionsFromClientMessage;
@class COSynchronizerPushedRevisionsToClientMessage;
@class COSynchronizerResponseToClientForSentRevisionsMessage;
@class COSynchronizerPersistentRootInfoToClientMessage;

@protocol COSynchronizerClientDelegate <NSObject>

- (void) sendPushToServer: (COSynchronizerPushedRevisionsFromClientMessage *)message;

@end

/*
 
 Properties of this sync protocol:
 
 - low latency: only a one way trip from c->s or s->c is needed for each change
 (c = COSynchronizerClient, s = COSynchronizerServer)
 (although responses are sent from s->c to make the client converge, and from c->s
 so that the server won't send more redundant commits than it has to)
 Note though that if this is hosted over XMPP all messages go through
 the xmpp server which will add latency. (c->XMPP Server->s, s->XMPP Server->c)
 
 - the maximum latency is getting changes between two clients, which is c->s->c.
  This will be pretty bad over XMPP since it will be
 c->XMPP Server->s->XMPP Server->c
 
 - guaranteed convergence of all clients to the server's history
 
 - server can be a regular user editing as well
 
 - supports any number of people sharing
 
 - very asychronous.
 
   The only restriction is, the client has to wait for a receipt before
   sending more commits to the server (but can continue to make commits locally)
 
 - correctly converges even in the case when both the client and server
  are have in-flight edits to each other. (the client ignores the edits
 from the server. The server merges the clients changes, and then sends the
 client the merge results)
 
 - multi-user undo friendly. COUndoTrack just works, even in the face of 
 local commits that are recorded in the undo track are rebased against
 server changes. This just works with no special effort, the only requirement
 is that the un-rebased changes need to be not garbage collected for COUndoTrack
 to work. A 30-day no garbage collection policy will take care of this,
 or the GC could scan for refs in the undo database.
 
 - tolerant of any messages being dropped, or being delivered in any order
 
 */
@interface COSynchronizerClient : NSObject
{
	COEditingContext *_ctx;
	COBranch *_branch;
	NSString *_clientID;
	
	ETUUID *_lastRevisionUUIDFromServer;
	ETUUID *_lastRevisionUUIDInTransitToServer;
	
	id<COSynchronizerClientDelegate> _delegate;
}

- (id) initWithSetupMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
				   clientID: (NSString *)clientID
			 editingContext: (COEditingContext *)ctx;


@property (nonatomic, readonly, strong) NSString *clientID;

@property (nonatomic, readonly, strong) COPersistentRoot *persistentRoot;
@property (nonatomic, readonly, strong) COBranch *branch;

@property (nonatomic, readwrite, strong) id<COSynchronizerClientDelegate> delegate;

- (void) handlePushMessage: (COSynchronizerPushedRevisionsToClientMessage *)aMessage;
- (void) handleResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aMessage;

@end
