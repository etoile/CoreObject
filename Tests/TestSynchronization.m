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

- (void)testBasic
{
    COPersistentRootInfo *info = [serverStore createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                                  UUID: persistentRootUUID
                                                                            branchUUID: branchAUUID
                                                                      revisionMetadata: nil
                                                                                 error: NULL];
    UKNotNil(info);
    
    COSynchronizationClient *client = [[[COSynchronizationClient alloc] init] autorelease];
    COSynchronizationServer *server = [[[COSynchronizationServer alloc] init] autorelease];
    
    id request = [client updateRequestForPersistentRoot: persistentRootUUID store: store];
    id response = [server handleUpdateRequest: request store: serverStore];
    [client handleUpdateResponse: response store: store];    
}

@end

