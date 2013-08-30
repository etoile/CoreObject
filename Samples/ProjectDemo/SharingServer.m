#import "SharingServer.h"
#import <CoreObject/CoreObject.h>
#import "NetworkController.h"

@implementation SharingServer

- (id) initWithDocument: (Document*)d
{
	self = [super init];
	ASSIGN(doc, d);
	peers = [[NSMutableDictionary alloc] init];

	// FIXME:
//	[[NSNotificationCenter defaultCenter] addObserver: self
//											 selector: @selector(didCommit:)
//												 name: COEditingContextBaseHistoryGraphNodeDidChangeNotification
//											   object: [[NSApp delegate] editingContext]];
	
	ASSIGN(sessionID, [ETUUID UUID]);
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[peers release];
	[doc release];
	[sessionID release];
	[super dealloc];
}

- (ETUUID*) sessionID
{
	return sessionID;
}
- (Document*) document
{
	return doc;
}
/* COStoreCoordinator notification */

- (void)didCommit: (NSNotification*)notif
{
	for (SharingServerPeer *peer in [peers allValues])
	{
		[peer synchronizeWithClientIfPossible];
	}
}

- (BOOL)isSharedWithClientNamed: (NSString*)name
{
	return (nil != [peers objectForKey: name]);
}

- (void)addClientNamed: (NSString*)name
{
	SharingServerPeer *p = [[SharingServerPeer alloc] initWithSharingSession: self 
																  clientName: name];
	[peers setObject: p
			  forKey: name];
	[p release];
}
- (void)removeClientNamed: (NSString*)name
{
	[peers removeObjectForKey: name];
}

- (void)handleMessage: (NSDictionary*)msg
{
	/*
	 
	 { messagetype : sharingMessageFromClient,
	 clientName : name
	 shadowHistoryGraphNodeUUID : uuid,
	 commits : ( ),  // a series of commits based on shadowHistoryGraphNode
	 }
	 */
	NSString *clientName = [msg objectForKey: @"clientName"];
	SharingServerPeer *peer = [peers objectForKey: clientName];
	
	assert(peer != nil);
	
	[peer handleMessage: msg];
}

@end
