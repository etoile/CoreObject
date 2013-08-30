#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

#define SERVER_STORE_URL [NSURL fileURLWithPath: [@"~/TestStore2.sqlite" stringByExpandingTildeInPath]]

@interface TestSynchronization : TestCommon <UKTest>
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
    
    id request = [client updateRequestForPersistentRoot: persistentRootUUID store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    // Persistent root has been replicated to the client
    
    COPersistentRootInfo *clientInfo = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo);
    UKObjectsEqual([[serverInfo currentRevisionID] revisionUUID], [[clientInfo currentRevisionID] revisionUUID]);
    UKObjectsEqual([self itemGraphWithLabel: @"1"], [store itemGraphForRevisionID: [clientInfo currentRevisionID]]);
    
    UKTrue([[[[clientInfo currentBranchInfo] metadata] objectForKey: @"source"] isEqual: @"server"]);
    UKTrue([[[[clientInfo currentBranchInfo] metadata] objectForKey: @"replcatedBranch"] isEqual: [branchAUUID stringValue]]);
    UKFalse([[[clientInfo currentBranchInfo] UUID] isEqual: branchAUUID]);
}

- (void)testPullUpdates
{
    COPersistentRootInfo *serverInfo = [serverStore createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                                        UUID: persistentRootUUID
                                                                                  branchUUID: branchAUUID
                                                                            revisionMetadata: nil
                                                                                       error: NULL];

    COPersistentRootInfo *clientInfo = [store createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                                  UUID: persistentRootUUID
                                                                            branchUUID: branchAUUID
                                                                      revisionMetadata: nil
                                                                                 error: NULL];
    
    // Server writes a second commit.
    
    CORevisionID *serverCommit2 = [serverStore writeRevisionWithItemGraph: [self itemGraphWithLabel: @"2"]
                                                                 metadata: nil
                                                         parentRevisionID: [serverInfo currentRevisionID]
                                                    mergeParentRevisionID: nil
                                                            modifiedItems: nil
                                                                    error: NULL];
    
    // Pull from server to client
    
    COSynchronizationClient *client = [[[COSynchronizationClient alloc] init] autorelease];
    COSynchronizationServer *server = [[[COSynchronizationServer alloc] init] autorelease];
    
    id request = [client updateRequestForPersistentRoot: persistentRootUUID store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];
    
    // Persistent root has been replicated to the client
    
    COPersistentRootInfo *clientInfo2 = [store persistentRootInfoForUUID: persistentRootUUID];
    UKNotNil(clientInfo2);
    NSSet *replicatedBranches = [SA([clientInfo2 branches]) objectsPassingTest: ^(id obj, BOOL *stop){
        if (![[[obj metadata] objectForKey: @"source"] isEqual: @"server"]) return NO;
        if (![[[obj metadata] objectForKey: @"replcatedBranch"] isEqual: [branchAUUID stringValue]]) return NO;
        return YES;
    }];
    
    UKIntsEqual(1, [replicatedBranches count]);
    COBranchInfo *replicatedBranch = [replicatedBranches anyObject];
    
    // Only the replicated branch should have been update.
    
    UKObjectsEqual([self itemGraphWithLabel: @"2"], [store itemGraphForRevisionID: [replicatedBranch currentRevisionID]]);
    UKObjectsEqual([self itemGraphWithLabel: @"1"], [store itemGraphForRevisionID: [clientInfo2 currentRevisionID]]);
}

@end

