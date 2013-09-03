#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

#define SERVER_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore2.sqlite" stringByExpandingTildeInPath]]

@interface TestSynchronization : EditingContextTestCase <UKTest>
{
    COSQLiteStore *serverStore;
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
    COMutableItem *child = [[[COMutableItem alloc] initWithUUID: rootItemUUID] autorelease];
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
    DESTROY(serverStore);
    [[NSFileManager defaultManager] removeItemAtPath: [SERVER_STORE_URL path] error: NULL];
	[super dealloc];
}

- (void)testReplicateToClientWithoutPersistentRoot
{
    COPersistentRootInfo *serverInfo = [serverStore createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                                        UUID: persistentRootUUID
                                                                                  branchUUID: branchAUUID
                                                                            revisionMetadata: nil
                                                                                       error: NULL];
    UKNotNil(serverInfo);
    
    // Client doesn't have the persistent root. It asks to pull from the server.
    
    COSynchronizationClient *client = [[[COSynchronizationClient alloc] init] autorelease];
    COSynchronizationServer *server = [[[COSynchronizationServer alloc] init] autorelease];
    
    id request = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    // Persistent root has been replicated to the client
    
    COPersistentRootInfo *clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    
    UKIntsEqual(1, [[clientInfo branches] count]);
    UKNil([clientInfo currentBranchUUID]);
    
    COBranchInfo *replicatedBranch = [clientInfo branches][0];
    
    UKObjectsEqual([[serverInfo currentRevisionID] revisionUUID], [[replicatedBranch currentRevisionID] revisionUUID]);
    UKObjectsEqual([self itemGraphWithLabel: @"1"], [store itemGraphForRevisionID: [replicatedBranch currentRevisionID]]);
    
    UKTrue([[[replicatedBranch metadata] objectForKey: @"source"] isEqual: @"server"]);
    UKTrue([[[replicatedBranch metadata] objectForKey: @"replcatedBranch"] isEqual: [branchAUUID stringValue]]);
    UKFalse([[replicatedBranch UUID] isEqual: branchAUUID]);
}

- (void)testPullUpdates
{
    COSynchronizationClient *client = [[[COSynchronizationClient alloc] init] autorelease];
    COSynchronizationServer *server = [[[COSynchronizationServer alloc] init] autorelease];
    
    COPersistentRootInfo *serverInfo = [serverStore createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                                        UUID: persistentRootUUID
                                                                                  branchUUID: branchAUUID
                                                                            revisionMetadata: nil
                                                                                       error: NULL];

    // Pull from server to client
        
    id request = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    COPersistentRootInfo *clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    
    // Server writes a second commit.
    
    CORevisionID *serverCommit2 = [serverStore writeRevisionWithItemGraph: [self itemGraphWithLabel: @"2"]
                                                                 metadata: nil
                                                         parentRevisionID: [serverInfo currentRevisionID]
                                                    mergeParentRevisionID: nil
                                                            modifiedItems: nil
                                                                    error: NULL];
    int64_t changeCount = serverInfo.changeCount;
    UKTrue([serverStore setCurrentRevision: serverCommit2
                              headRevision: serverCommit2
                              tailRevision: nil
                                 forBranch: branchAUUID
                          ofPersistentRoot: persistentRootUUID
                        currentChangeCount: &changeCount
                                     error: NULL]);
    
    // Pull from server to client
    
    id request2 = [client updateRequestForPersistentRoot: persistentRootUUID
                                               serverID: @"server"
                                                  store: store];
    id response2 = [server handleUpdateRequest: request2 store: serverStore];
    [client handleUpdateResponse: response2 store: store];
    
    // Persistent root has been replicated to the client
    
    clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    
    UKIntsEqual(1, [[clientInfo branches] count]);
    UKNil([clientInfo currentBranchUUID]);
    
    COBranchInfo *replicatedBranch = [clientInfo branches][0];
    UKTrue([[[replicatedBranch metadata] objectForKey: @"source"] isEqual: @"server"]);
    UKTrue([[[replicatedBranch metadata] objectForKey: @"replcatedBranch"] isEqual: [branchAUUID stringValue]]);
    
    // The replicated branch should have been update.
    
    UKObjectsEqual([self itemGraphWithLabel: @"2"], [store itemGraphForRevisionID: [replicatedBranch currentRevisionID]]);
}

- (void)testPullCheapCopy
{
    COSynchronizationClient *client = [[[COSynchronizationClient alloc] init] autorelease];
    COSynchronizationServer *server = [[[COSynchronizationServer alloc] init] autorelease];

    COPersistentRootInfo *serverInfo = [serverStore createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                                        UUID: persistentRootUUID
                                                                                  branchUUID: branchAUUID
                                                                            revisionMetadata: nil
                                                                                       error: NULL];
    
    ETUUID *cheapCopyUUID = [ETUUID UUID];
    ETUUID *cheapCopyBranchUUID = [ETUUID UUID];
    COPersistentRootInfo *serverCheapCopyInfo = [serverStore createPersistentRootWithInitialRevision: [serverInfo currentRevisionID]
                                                                                                UUID: cheapCopyUUID
                                                                                          branchUUID: cheapCopyBranchUUID
                                                                                               error: NULL];    
    // Server writes a second commit.
    
    CORevisionID *serverCommit2 = [serverStore writeRevisionWithItemGraph: [self itemGraphWithLabel: @"2"]
                                                                 metadata: nil
                                                         parentRevisionID: [serverCheapCopyInfo currentRevisionID]
                                                    mergeParentRevisionID: nil
                                                            modifiedItems: nil
                                                                    error: NULL];

    int64_t changeCount = serverInfo.changeCount;
    UKTrue([serverStore setCurrentRevision: serverCommit2
                              headRevision: serverCommit2
                              tailRevision: nil
                                 forBranch: cheapCopyBranchUUID
                          ofPersistentRoot: cheapCopyUUID
                        currentChangeCount: &changeCount
                                     error: NULL]);
    
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
    UKIntsEqual(1, [[clientCheapCopyInfo branches] count]);
    UKObjectsEqual([self itemGraphWithLabel: @"2"],
                   [store itemGraphForRevisionID: [[clientCheapCopyInfo branches][0] currentRevisionID]]);
    
    // Ideally it shares the same backing store as the original persistent root. But that's not going to be easy to do.
}

@end

