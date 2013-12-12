#import <Foundation/Foundation.h>
#import <CoreObject/CoreObject.h>
#import <CoreObject/COSynchronizerClient.h>

@class COSynchronizerAcknowledgementFromClientMessage;
@class COSynchronizerPushedRevisionsFromClientMessage;
@class COSynchronizerPushedRevisionsToClientMessage;
@class COSynchronizerResponseToClientForSentRevisionsMessage;
@class COSynchronizerPersistentRootInfoToClientMessage;

@protocol COSynchronizerServerDelegate <NSObject>

- (void) sendResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)aPropertyList
					toClient: (NSString *)aJID;
- (void) sendPushedRevisions: (COSynchronizerPushedRevisionsToClientMessage *)aMessage
				   toClients: (NSArray *)clients;
- (void) sendPersistentRootInfoMessage: (COSynchronizerPersistentRootInfoToClientMessage *)aMessage
							  toClient: (NSString *)aClient;

@end

@interface COSynchronizerServer : NSObject
{
	COBranch *branch;

	/**
	 * Keys in this dictionary determine the active set of clients
	 */
	NSMutableDictionary *lastSentRevisionForClientID;
	
	id<COSynchronizerServerDelegate> delegate;
	
	// HACK: These two are used to pass info between two methods in
	// COSynchronizerServer where one calls the other via a commit notification
	
	ETUUID *currentlyHandlingLastSentRevision;
	NSString *currentlyRespondingToClient;
}

- (id) initWithBranch: (COBranch *)aBranch;

@property (nonatomic, readonly, strong) COPersistentRoot *persistentRoot;
@property (nonatomic, readonly, strong) COBranch *branch;

@property (nonatomic, readwrite, strong) id<COSynchronizerServerDelegate> delegate;

- (void) handlePushedRevisionsFromClient: (COSynchronizerPushedRevisionsFromClientMessage *)aMessage;

- (void) addClientID: (NSString *)clientID;
- (void) removeClientID: (NSString *)clientID;

@property (nonatomic, readonly) NSArray *clientIDs;

@end

