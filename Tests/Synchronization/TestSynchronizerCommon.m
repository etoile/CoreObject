/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  November 2013
	License:  MIT  (see COPYING)
 */


#import "TestSynchronizerCommon.h"

@implementation TestSynchronizerCommon

- (id) init
{
	SUPERINIT;
	
	[[[COSQLiteStore alloc] initWithURL: CLIENT_STORE_URL] clearStore];
	
	serverPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupNoOpposite"];
	serverPersistentRoot.metadata = [self persistentRootMetadataForTest];
	serverBranch = [serverPersistentRoot currentBranch];
	serverBranch.metadata = [self branchMetadataForTest];
	[ctx commit];
	
	server = [[COSynchronizerServer alloc] initWithBranch: serverBranch];
	transport = [[[[self class] messageTransportClass] alloc] initWithSynchronizerServer: server];
	
	clientCtx = [COEditingContext contextWithURL: CLIENT_STORE_URL];
	client = [[COSynchronizerClient alloc] initWithClientID: @"client" editingContext: clientCtx];
	
	// Transmits the persistent root to the client
	[transport addClient: client];
	
	clientPersistentRoot = client.persistentRoot;
	clientBranch = client.branch;
	
	ETAssert(clientPersistentRoot != nil);
	ETAssert(clientBranch != nil);
	
	return self;
}

+ (Class) messageTransportClass
{
	return [FakeMessageTransport class];
}

- (void)dealloc
{
	NSError *error = nil;
	
    [[NSFileManager defaultManager] removeItemAtURL: CLIENT_STORE_URL error: &error];
	ETAssert(error == nil);
}

- (NSDictionary *)serverRevisionMetadataForTest
{
	return @{ @"testMetadata" : @"server"};
}

- (NSDictionary *)clientRevisionMetadataForTest
{
	return @{ @"testMetadata" : @"client"};
}

- (NSDictionary *)branchMetadataForTest
{
	return @{ kCOBranchLabel : @"my branch" };
}

- (NSDictionary *)persistentRootMetadataForTest
{
	return @{ COPersistentRootName : @"my persistent root" };
}

- (UnorderedGroupNoOpposite *) addAndCommitServerChild
{
	UnorderedGroupNoOpposite *serverChild1 = [[serverBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.UnorderedGroupNoOpposite"];
	[[[serverBranch rootObject] mutableSetValueForKey: @"contents"] addObject: serverChild1];
	[serverPersistentRoot commitWithMetadata: [self serverRevisionMetadataForTest]];
	return serverChild1;
}

- (UnorderedGroupNoOpposite *) addAndCommitClientChild
{
	UnorderedGroupNoOpposite *clientChild1 = [[clientBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.UnorderedGroupNoOpposite"];
	[[[clientBranch rootObject] mutableSetValueForKey: @"contents"] addObject: clientChild1];
	[clientPersistentRoot commitWithMetadata: [self clientRevisionMetadataForTest]];
	return clientChild1;
}

- (NSArray *)serverMessages
{
	return [transport serverMessages];
}

- (NSArray *)clientMessages
{
	return [transport messagesForClient: client.clientID];
}

@end