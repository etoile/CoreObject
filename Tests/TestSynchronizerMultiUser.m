#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COSynchronizerFakeMessageTransport.h"

#define CLIENT1_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore2.sqlite" stringByExpandingTildeInPath]]
#define CLIENT2_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore3.sqlite" stringByExpandingTildeInPath]]

@interface TestSynchronizerMultiUser : EditingContextTestCase <UKTest>
{
	COSynchronizerServer *server;
	COPersistentRoot *serverPersistentRoot;
	COBranch *serverBranch;
	
	FakeMessageTransport *transport;
	
	COSynchronizerClient *client1;
	COEditingContext *client1Ctx;
	COPersistentRoot *client1PersistentRoot;
	COBranch *client1Branch;
	
	COSynchronizerClient *client2;
	COEditingContext *client2Ctx;
	COPersistentRoot *client2PersistentRoot;
	COBranch *client2Branch;
}
@end

@implementation TestSynchronizerMultiUser

- (id) init
{
	SUPERINIT;
	
	[[[COSQLiteStore alloc] initWithURL: CLIENT1_STORE_URL] clearStore];
	[[[COSQLiteStore alloc] initWithURL: CLIENT2_STORE_URL] clearStore];
	
	serverPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	serverBranch = [serverPersistentRoot currentBranch];
	[ctx commit];
	
	server = [[COSynchronizerServer alloc] initWithBranch: serverBranch];
	transport = [[FakeMessageTransport alloc] initWithSynchronizerServer: server];
	
	client1Ctx = [COEditingContext contextWithURL: CLIENT1_STORE_URL];
	client1 = [[COSynchronizerClient alloc] initWithClientID: @"client1" editingContext: client1Ctx];
	
	[transport addClient: client1];
	
	client1PersistentRoot = client1.persistentRoot;
	client1Branch = client1.branch;

	client2Ctx = [COEditingContext contextWithURL: CLIENT2_STORE_URL];
	client2 = [[COSynchronizerClient alloc] initWithClientID: @"client2" editingContext: client2Ctx];
	
	[transport addClient: client2];
	
	client2PersistentRoot = client2.persistentRoot;
	client2Branch = client2.branch;
	
	ETAssert(client1PersistentRoot != nil);
	ETAssert(client1Branch != nil);
	ETAssert(client2PersistentRoot != nil);
	ETAssert(client2Branch != nil);

	return self;
}

@end

