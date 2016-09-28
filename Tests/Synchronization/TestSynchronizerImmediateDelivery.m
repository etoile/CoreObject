/*
    Copyright (C) 2014 Eric Wasylishen

    Date:  September 2014
    License:  MIT  (see COPYING)
 */

#import "TestSynchronizerCommon.h"

@interface TestSynchronizerImmediateDelivery : TestSynchronizerCommon <UKTest>
@end


@implementation TestSynchronizerImmediateDelivery

+ (Class)messageTransportClass
{
    return [ImmediateMessageTransport class];
}

- (void)testPersistentRootMetadataReplicated
{
    UKObjectsEqual([self persistentRootMetadataForTest], clientPersistentRoot.metadata);
}

- (void)testBranchMetadataReplicated
{
    UKObjectsEqual([self branchMetadataForTest], clientBranch.metadata);
}

- (void)testBasicReplicationToClient
{
    UKNotNil(clientPersistentRoot);
    UKNotNil(clientBranch);
    UKNotNil(clientPersistentRoot.currentBranch);
    UKObjectsSame(clientBranch, clientPersistentRoot.currentBranch);
    UKObjectsEqual(serverPersistentRoot.UUID, clientPersistentRoot.UUID);
    UKObjectsEqual(serverBranch.UUID, clientBranch.UUID);
    UKObjectsEqual([serverBranch.rootObject UUID], [clientBranch.rootObject UUID]);
}

- (void)testClientEdit
{
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];

    UKIntsEqual(1, [[serverBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID),
                   [serverBranch.rootObject valueForKeyPath: @"contents.UUID"]);
}

- (void)testServerEdit
{
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];

    UKIntsEqual(1, [[clientBranch.rootObject contents] count]);
    UKObjectsEqual(S(serverChild1.UUID),
                   [clientBranch.rootObject valueForKeyPath: @"contents.UUID"]);
}

- (void)checkClientChild: (UnorderedGroupNoOpposite *)clientChild1
             serverChild: (UnorderedGroupNoOpposite *)serverChild1
{
    UKIntsEqual(2, [[serverBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [serverBranch.rootObject valueForKeyPath: @"contents.UUID"]);

    UKIntsEqual(2, [[clientBranch.rootObject contents] count]);
    UKObjectsEqual(S(clientChild1.UUID, serverChild1.UUID),
                   [clientBranch.rootObject valueForKeyPath: @"contents.UUID"]);
}

- (void)testClientAndServerEdit
{
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
    [self checkClientChild: clientChild1 serverChild: serverChild1];
}

- (void)testServerAndClientEdit
{
    UnorderedGroupNoOpposite *serverChild1 = [self addAndCommitServerChild];
    UnorderedGroupNoOpposite *clientChild1 = [self addAndCommitClientChild];
    [self checkClientChild: clientChild1 serverChild: serverChild1];
}

@end
