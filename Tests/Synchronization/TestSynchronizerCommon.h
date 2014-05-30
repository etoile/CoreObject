/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  November 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COSynchronizerFakeMessageTransport.h"
#import "TestAttributedStringCommon.h"

#define CLIENT_STORE_URL [[SQLiteStoreTestCase temporaryURLForTestStorage] URLByAppendingPathComponent: @"TestStore2.sqlite"]

@interface TestSynchronizerCommon : EditingContextTestCase <UKTest>
{
	COSynchronizerServer *server;
	COPersistentRoot *serverPersistentRoot;
	COBranch *serverBranch;
	
	FakeMessageTransport *transport;
	
	COSynchronizerClient *client;
	COEditingContext *clientCtx;
	COPersistentRoot *clientPersistentRoot;
	COBranch *clientBranch;
}

- (UnorderedGroupNoOpposite *) addAndCommitServerChild;
- (UnorderedGroupNoOpposite *) addAndCommitClientChild;

- (NSDictionary *)serverRevisionMetadataForTest;
- (NSDictionary *)clientRevisionMetadataForTest;

- (NSDictionary *)branchMetadataForTest;
- (NSDictionary *)persistentRootMetadataForTest;

- (NSArray *)serverMessages;
- (NSArray *)clientMessages;

@end
