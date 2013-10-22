#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

#define SERVER_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore2.sqlite" stringByExpandingTildeInPath]]

@interface TestSynchronization : EditingContextTestCase <UKTest>
{
    COSQLiteStore *serverStore;
	int64_t serverChangeCount;
}
@end

@implementation TestSynchronization

static ETUUID *persistentRootUUID;
static ETUUID *rootItemUUID;
static ETUUID *branchAUUID;
static ETUUID *branchBUUID;

+ (void) initialize
{
    if (self == [TestSynchronization class])
    {
        rootItemUUID = [[ETUUID alloc] init];
        persistentRootUUID = [[ETUUID alloc] init];
        branchAUUID = [[ETUUID alloc] init];
        branchBUUID = [[ETUUID alloc] init];
    }
}

- (COItemGraph *) itemGraphWithLabel: (NSString *)aLabel
{
    COMutableItem *child = [[COMutableItem alloc] initWithUUID: rootItemUUID];
    [child setValue: aLabel
       forAttribute: @"label"
               type: kCOTypeString];
    return [COItemGraph itemGraphWithItemsRootFirst: @[child]];
}

- (id)init
{
	SUPERINIT;
    [[NSFileManager defaultManager] removeItemAtPath: [SERVER_STORE_URL path] error: NULL];
    serverStore = [[COSQLiteStore alloc] initWithURL: SERVER_STORE_URL];
	return self;
}

- (void)dealloc
{
    [[NSFileManager defaultManager] removeItemAtPath: [SERVER_STORE_URL path] error: NULL];
}

- (void)testReplicateToClientWithoutPersistentRoot
{
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    COPersistentRootInfo *serverInfo = [txn createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
																				UUID: persistentRootUUID
																		  branchUUID: branchAUUID
																	revisionMetadata: nil];
    UKNotNil(serverInfo);
	[txn createBranchWithUUID: branchBUUID
				 parentBranch: nil
			  initialRevision: [serverInfo currentRevisionUUID]
			forPersistentRoot: persistentRootUUID];
    UKObjectsEqual(branchAUUID, [serverInfo currentBranchUUID]);
	serverChangeCount = [txn setOldTransactionID: -1 forPersistentRoot: persistentRootUUID];
    UKTrue([serverStore commitStoreTransaction: txn]);
    
    /* 
       * = current branch
     
       Server: persistent root { branch A *, branch B }
    
       Client: nothing
     */
    
    // Client doesn't have the persistent root. It asks to pull from the server.
    
    COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
    COSynchronizationServer *server = [[COSynchronizationServer alloc] init];
    
    id request = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    // Persistent root has been replicated to the client

    /*
       * = current branch
     
       Server: persistent root { branch A *, branch B }
     
       Client: persistent root { branch A *, branch C (mirror of server's branch A), branch D (mirror of server's branch B) }
     */
    
    COPersistentRootInfo *clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    
    UKIntsEqual(3, [[clientInfo branches] count]);
    
    COBranchInfo *currentBranch = [clientInfo currentBranchInfo];
    COBranchInfo *replicatedBranchA = [[clientInfo branchInfosWithMetadataValue: [branchAUUID stringValue]
                                                                         forKey: @"replcatedBranch"] firstObject];
    

    COBranchInfo *replicatedBranchB = [[clientInfo branchInfosWithMetadataValue: [branchBUUID stringValue]
                                                                         forKey: @"replcatedBranch"] firstObject];

    // Check out the 3 branches
    UKObjectsEqual(branchAUUID, [currentBranch UUID]);
    
    UKNotNil(replicatedBranchB);
    UKObjectsNotEqual(branchBUUID, [replicatedBranchB UUID]);

    UKNotNil(replicatedBranchA);
    UKObjectsNotEqual(branchAUUID, [replicatedBranchA UUID]);
    
    // Check out the revisions of the branches

    UKObjectsEqual([serverInfo currentRevisionUUID], [currentBranch currentRevisionUUID]);
    UKObjectsEqual([serverInfo currentRevisionUUID], [replicatedBranchA currentRevisionUUID]);
    UKObjectsEqual([serverInfo currentRevisionUUID], [replicatedBranchB currentRevisionUUID]);
    
	UKObjectsEqual([self itemGraphWithLabel: @"1"], [self currentItemGraphForBranch: [currentBranch UUID]]);
    UKObjectsEqual([self itemGraphWithLabel: @"1"], [self currentItemGraphForBranch: [replicatedBranchA UUID]]);
    UKObjectsEqual([self itemGraphWithLabel: @"1"], [self currentItemGraphForBranch: [replicatedBranchB UUID]]);
    
    UKNil([[currentBranch metadata] objectForKey: @"source"]);
    UKObjectsEqual(@"server", [[replicatedBranchA metadata] objectForKey: @"source"]);
    UKObjectsEqual(@"server", [[replicatedBranchB metadata] objectForKey: @"source"]);
}

- (void)testPullUpdates
{
    COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
    COSynchronizationServer *server = [[COSynchronizationServer alloc] init];
    
	COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    COPersistentRootInfo *serverInfo = [txn createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
																				UUID: persistentRootUUID
																		  branchUUID: branchAUUID
																	revisionMetadata: nil];
	serverChangeCount = [txn setOldTransactionID: -1 forPersistentRoot: persistentRootUUID];
    UKTrue([serverStore commitStoreTransaction: txn]);

    // Pull from server to client
        
    id request = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    COPersistentRootInfo *clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    
    // Server writes a second commit.
    
    txn = [[COStoreTransaction alloc] init];
    ETUUID *serverCommit2 = [ETUUID UUID];
	
	[txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"2"]
						   revisionUUID: serverCommit2
							   metadata: nil
					   parentRevisionID: [serverInfo currentRevisionUUID]
				  mergeParentRevisionID: nil
					 persistentRootUUID: persistentRootUUID
							 branchUUID: branchAUUID];

    [txn setCurrentRevision: serverCommit2
			   headRevision: nil
				  forBranch: branchAUUID
		   ofPersistentRoot: persistentRootUUID];
	
	serverChangeCount = [txn setOldTransactionID: serverChangeCount forPersistentRoot: persistentRootUUID];
	
    UKTrue([serverStore commitStoreTransaction: txn]);
    
    // Pull from server to client
    
    id request2 = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response2 = [server handleUpdateRequest: request2 store: serverStore];
    [client handleUpdateResponse: response2 store: store];
    
    // Persistent root has been replicated to the client
    
    clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    
    UKIntsEqual(2, [[clientInfo branches] count]);

    COBranchInfo *currentBranch = [clientInfo currentBranchInfo];
    
    COBranchInfo *replicatedBranchA = [[clientInfo branchInfosWithMetadataValue: [branchAUUID stringValue]
                                                                         forKey: @"replcatedBranch"] firstObject];
    
    UKTrue([[[replicatedBranchA metadata] objectForKey: @"source"] isEqual: @"server"]);
    
    // The replicated branch should have been update, but the other branch should not have
    
    UKObjectsEqual([self itemGraphWithLabel: @"1"], [self currentItemGraphForBranch: [currentBranch UUID]]);
    UKObjectsEqual([self itemGraphWithLabel: @"2"], [self currentItemGraphForBranch: [replicatedBranchA UUID]]);
}

- (void)testPullCheapCopy
{
    COSynchronizationClient *client = [[COSynchronizationClient alloc] init];
    COSynchronizationServer *server = [[COSynchronizationServer alloc] init];

    COStoreTransaction *txn = [[COStoreTransaction alloc] init];
    COPersistentRootInfo *serverInfo = [txn createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
																				UUID: persistentRootUUID
																		  branchUUID: branchAUUID
																	revisionMetadata: nil];
    
    ETUUID *cheapCopyUUID = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID = [ETUUID UUID];
    COPersistentRootInfo *serverCheapCopyInfo = [txn createPersistentRootCopyWithUUID: cheapCopyUUID
															 parentPersistentRootUUID: persistentRootUUID
																		   branchUUID: cheapCopyBranchUUID
																	 parentBranchUUID: nil
																  initialRevisionUUID: [serverInfo currentRevisionUUID]];
	
    // Server writes a second commit.
    
    ETUUID *serverCommit2 = [ETUUID UUID];
	
	[txn writeRevisionWithModifiedItems: [self itemGraphWithLabel: @"2"]
						   revisionUUID: serverCommit2
							   metadata: nil
					   parentRevisionID: [serverCheapCopyInfo currentRevisionUUID]
				  mergeParentRevisionID: nil
					 persistentRootUUID: cheapCopyUUID
							 branchUUID: branchAUUID];

	[txn setCurrentRevision: serverCommit2
			   headRevision: nil
				  forBranch: cheapCopyBranchUUID
		   ofPersistentRoot: cheapCopyUUID];
    
    UKTrue([serverStore commitStoreTransaction: txn]);
    
    // Replicate the original persistent root on the client
    
    // Pull from server to client
    
    id request = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    COPersistentRootInfo *clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);

    //NSLog(@"Server: %@", serverStore);
    //NSLog(@"Client: %@", store);
    
    // Pull "cheapCopyUUID" persistent root from server to client
        
    id request2 = [client updateRequestForPersistentRoot: cheapCopyUUID
                                               serverID: @"server"
                                                  store: store];
    id response2 = [server handleUpdateRequest: request2 store: serverStore];
    [client handleUpdateResponse: response2 store: store];
    
    // "cheapCopyUUID" persistent root has been replicated to the client.
    
    COPersistentRootInfo *clientCheapCopyInfo = [store persistentRootInfoForUUID: cheapCopyUUID];
    UKIntsEqual(2, [[clientCheapCopyInfo branches] count]);
    
    COBranchInfo *currentBranch = [clientCheapCopyInfo currentBranchInfo];
    COBranchInfo *replicatedCheapCopyBranch = [[clientCheapCopyInfo branchInfosWithMetadataValue: [cheapCopyBranchUUID stringValue]
                                                                                          forKey: @"replcatedBranch"] firstObject];

    UKObjectsEqual(cheapCopyBranchUUID, [currentBranch UUID]);
    UKObjectsNotEqual(cheapCopyBranchUUID, [replicatedCheapCopyBranch UUID]);
    
    UKObjectsEqual([self itemGraphWithLabel: @"2"], [self currentItemGraphForBranch: [currentBranch UUID]]);
    UKObjectsEqual([self itemGraphWithLabel: @"2"], [self currentItemGraphForBranch: [replicatedCheapCopyBranch UUID]]);
    
    // Ideally it shares the same backing store as the original persistent root. But that's not going to be easy to do.
}

@end

