#import "COSynchronizer.h"

#if 0
@implementation COSynchronizer

- (id)initWithStore: (COStore *)aStore
{
	SUPERINIT;
	shadowEditingContext = [[COEditingContext alloc] initWithStore: aStore];
	account = [[XMPPAccount alloc] init];
	return self;
}

- (void)dealloc
{
	DESTROY(shadowEditingContext);
	DESTROY(account);
	[super dealloc];
}

- (void)didCommitChangedObjects: (NSSet *)changedObjects
				  forRootObject: (COObject *)aRootObject
{
	/*COObjectGraphDiff *diff = [[COObjectGraphDiff new] autorelease];

	for (COObject *obj in changedObjects)
	{
		COObject *shadowObj = [shadowEditingContext objectWithUUID: [obj UUID]];
		[COObjectGraphDiff _diffObject: shadowObj with: obj addToDiff: diff];
	}*/

	NSSet *editedUUIDs = [[changedObjects mappedCollection] UUID];
	COObjectGraphDiff *diff = [COObjectGraphDiff diffObjectsWithUUIDs: editedUUIDs
															inContext: shadowEditingContext
														  withContext: [aRootObject editingContext]];

	[diff applyToContext: shadowEditingContext];
	[self synchronizeClientsUsingDiff: diff];
}

// TODO: Could ETXMLWriter to -propertyList and write COObjectGraphDiff
// serialization while multiplexing the writing over several streams
- (void)sendPatchData: (NSData *)patchData toPerson: (XMPPPerson *)aPerson
{
	ETXMLWriter *writer [[self conversationForPerson: aPerson] xmlWriter];
	
	// Send an <coreobject> tag on the stream indicating the application and
	// uudi data the receiving side may use for routing the object.
	[writer startElement: @"coreobject"
			  attributes: D(@"http://www.etoileos.com/CoreObject", @"xmlns",
							registeredName, @"application",
							[objUUID stringValue], @"uuid")];

	[writer startAndEndElement: @"diff"
					attributes: D(@"unknown", @"version")
						 cdata: [patchData base64String]];
	
	[writer endElement]; //</coreobject>
	[writer endElement]; //</message>
}

- (void)synchronizeClientsUsingDiff: (COObjectGraphDiff *)diff
{
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList: [diff propertyList]
	                                                               format: NSPropertyListXMLFormat_v1_0
	                                                     errorDescription: NULL];
	
	for (XMPPConversation *person in [self persons])
	{
		[self sendPatchData: plistData toPerson: person];
	}
}

- (XMPPConversation *)conversationForPerson: (XMPPPerson *)aPerson
{
	XMPPConversation *conversation = [XMPPConversation conversationForPerson: aPerson];

	if (conversation != nil)
	{
		[conversation setJID: [aPerson defaultIdentity] jid]];
		[[conversation delegate] activate: self];
	}
	else
	{
		conversation = [XMPPConversation conversationWithPerson: aPerson
													 forAccount: account]
	}
	return conversation;
}

@end
#endif
