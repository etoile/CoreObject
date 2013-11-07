#import "COSynchronizerServer.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerAcknowledgementFromClientMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"


@implementation COSynchronizerServer

@synthesize delegate;

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
	
}
- (void) handleReceiptFromClient: (COSynchronizerAcknowledgementFromClientMessage *)aMessage
{
	
}

@end
