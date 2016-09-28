/*
    Copyright (C) 2013 Eric Wasylishen
 
    Date:  November 2013
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COSynchronizerMessageTransport.h"
#import "COSynchronizerFakeMessageTransport.h"
#import "COSynchronizerImmediateMessageTransport.h"
#import "TestAttributedStringCommon.h"

#define CLIENT_STORE_URL [[SQLiteStoreTestCase temporaryURLForTestStorage] URLByAppendingPathComponent: @"TestStore2.sqlite"]

@interface TestSynchronizerCommon : EditingContextTestCase <UKTest>
{
    COSynchronizerServer *server;
    COPersistentRoot *serverPersistentRoot;
    COBranch *serverBranch;

    id <MessageTransport> transport;

    COSynchronizerClient *client;
    COEditingContext *clientCtx;
    COPersistentRoot *clientPersistentRoot;
    COBranch *clientBranch;
}

/**
 * Override return the message transport to use for the tests.
 */
+ (Class)messageTransportClass;

- (UnorderedGroupNoOpposite *)addAndCommitServerChild;
- (UnorderedGroupNoOpposite *)addAndCommitClientChild;

@property (nonatomic, readonly) NSDictionary *serverRevisionMetadataForTest;
@property (nonatomic, readonly) NSDictionary *clientRevisionMetadataForTest;
@property (nonatomic, readonly) NSDictionary *branchMetadataForTest;
@property (nonatomic, readonly) NSDictionary *persistentRootMetadataForTest;
@property (nonatomic, readonly) NSArray *serverMessages;
@property (nonatomic, readonly) NSArray *clientMessages;

@end
