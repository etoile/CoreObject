#import <Foundation/Foundation.h>

#if 0
@class COObjectGraphDiff;
@class XMPPAccount;

/**
 * COSynchronizer is a tool responsible for:
 * - live collaboration
 * - offline collaboration
 *
 * How should the synchronizer interact with branches? Ideally, mindful of them.
 * For example, if syncing two computers, you want the branches copied over.
 *
 * If someone does a revert to a old revision, everyone should get it? maybe not.
 * 
 
Use case:
 
 
problems:
 
 // Collect UUIDS of all objects changed AFTER the shadow node and before or on the baseHistoryGraphNode
 ----> is this hard in om2?
 shouldn't be.
 
 */
@interface COSynchronizer : NSObject
{
	COEditingContext *shadowEditingContext;
	XMPPAccount *account;
	XMPPConversation *conversation;
}

/** @taskunit Managing the Participants */

/**
 * Returns the client persons involved in a collaboration over one or several 
 * shared root objects.
 */
- (NSSet *)persons;
- (void)invitePerson: (XMPPPerson *)aPerson;
- (void)revokePerson: (XMPPPerson *)aPerson;


- (void)didCommitChangedObjects: (NSSet *)changedObjects
				  forRootObject: (COObject *)anObject;

- (void)synchronizeClientsUsingDiff: (COObjectGraphDiff *)aDiff;

/** @taskunit XMPP Integration */

- (XMPPConversation *)conversationForPerson: (XMPPPerson *)aPerson;

@end

#endif
