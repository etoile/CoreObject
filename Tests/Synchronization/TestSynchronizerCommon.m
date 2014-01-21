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
	serverBranch = [serverPersistentRoot currentBranch];
	[ctx commit];
	
	server = [[COSynchronizerServer alloc] initWithBranch: serverBranch];
	transport = [[FakeMessageTransport alloc] initWithSynchronizerServer: server];
	
	clientCtx = [COEditingContext contextWithURL: CLIENT_STORE_URL];
	client = [[COSynchronizerClient alloc] initWithClientID: @"client" editingContext: clientCtx];
	
	[transport addClient: client];
	
	clientPersistentRoot = client.persistentRoot;
	clientBranch = client.branch;
	
	ETAssert(clientPersistentRoot != nil);
	ETAssert(clientBranch != nil);
	
	return self;
}

- (void)dealloc
{
	NSError *error = nil;
	
    [[NSFileManager defaultManager] removeItemAtURL: CLIENT_STORE_URL error: &error];
	ETAssert(error == nil);
}

- (UnorderedGroupNoOpposite *) addAndCommitServerChild
{
	UnorderedGroupNoOpposite *serverChild1 = [[serverBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.UnorderedGroupNoOpposite"];
	[[[serverBranch rootObject] mutableSetValueForKey: @"contents"] addObject: serverChild1];
	[ctx commit];
	return serverChild1;
}

- (UnorderedGroupNoOpposite *) addAndCommitClientChild
{
	UnorderedGroupNoOpposite *clientChild1 = [[clientBranch objectGraphContext] insertObjectWithEntityName: @"Anonymous.UnorderedGroupNoOpposite"];
	[[[clientBranch rootObject] mutableSetValueForKey: @"contents"] addObject: clientChild1];
	[clientCtx commit];
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