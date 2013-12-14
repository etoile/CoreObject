/*
    Copyright (C) 2013 Eric Wasylishen

    Author:  Eric Wasylishen <ewasylishen@gmail.com>
    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import "COSynchronizerJSONServer.h"
#import "COSynchronizerJSONUtils.h"

#import "COSynchronizerRevision.h"
#import "COSynchronizerPushedRevisionsToClientMessage.h"
#import "COSynchronizerPushedRevisionsFromClientMessage.h"
#import "COSynchronizerResponseToClientForSentRevisionsMessage.h"
#import "COSynchronizerPersistentRootInfoToClientMessage.h"

@implementation COSynchronizerJSONServer

@synthesize delegate, server;

- (void) sendPropertyList: (id)aPropertyList toClient: (NSString *)aClient
{
	NSString *text = [COSynchronizerJSONUtils serializePropertyList: aPropertyList];
	[delegate JSONServer: self sendText: text toClient: aClient];
}

- (void) sendResponseMessage: (COSynchronizerResponseToClientForSentRevisionsMessage *)message
					toClient: (NSString *)aClient
{
	id plist = [NSMutableDictionary new];
	plist[@"lastRevisionUUIDSentByClient"] = [message.lastRevisionUUIDSentByClient stringValue];
	plist[@"revisions"] = [COSynchronizerJSONUtils propertyListForRevisionsArray:message.revisions];
	plist[@"class"] = @"COSynchronizerResponseToClientForSentRevisionsMessage";
	[self sendPropertyList: plist toClient: aClient];
}

- (void) sendPushedRevisions: (COSynchronizerPushedRevisionsToClientMessage *)message
				   toClients: (NSArray *)clients
{
	for (NSString *client in clients)
	{
		id plist = [NSMutableDictionary new];
		plist[@"revisions"] = [COSynchronizerJSONUtils propertyListForRevisionsArray:message.revisions];
		plist[@"class"] = @"COSynchronizerPushedRevisionsToClientMessage";
		[self sendPropertyList: plist toClient: client];
	}
}

- (void) sendPersistentRootInfoMessage: (COSynchronizerPersistentRootInfoToClientMessage *)message
							  toClient: (NSString *)aClient
{
	id plist = [NSMutableDictionary new];
	plist[@"persistentRootUUID"] = [message.persistentRootUUID stringValue];
	if (message.persistentRootMetadata != nil)
	{
		plist[@"persistentRootMetadata"] = message.persistentRootMetadata;
	}
	plist[@"branchUUID"] = [message.branchUUID stringValue];
	if (message.branchMetadata != nil)
	{
		plist[@"branchMetadata"] = message.branchMetadata;
	}
	plist[@"currentRevision"] = [message.currentRevision propertyList];
	plist[@"class"] = @"COSynchronizerPersistentRootInfoToClientMessage";
	[self sendPropertyList: plist toClient: aClient];
}

- (void) handlePushedRevisionsFromClientPropertyList: (id)plist
{
	COSynchronizerPushedRevisionsFromClientMessage *message = [COSynchronizerPushedRevisionsFromClientMessage new];
	message.clientID = plist[@"clientID"];
	message.revisions = [COSynchronizerJSONUtils revisionsArrayForPropertyList: plist[@"revisions"]];
	message.lastRevisionUUIDSentByServer = [ETUUID UUIDWithString: plist[@"lastRevisionUUIDSentByServer"]];
	[server handlePushedRevisionsFromClient: message];
}

- (void) receiveText: (NSString *)text fromClient: (NSString *)aClient
{
	id propertyList = [COSynchronizerJSONUtils deserializePropertyList: text];
	
	NSString *type = propertyList[@"class"];
	if ([type isEqual: @"COSynchronizerPushedRevisionsFromClientMessage"])
	{
		[self handlePushedRevisionsFromClientPropertyList: propertyList];
	}
	else
	{
		NSLog(@"COSynchronizerJSONClient: unknown message type: %@", type);
	}
}

@end
