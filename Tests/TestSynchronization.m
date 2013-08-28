#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestSynchronization : TestCommon <UKTest>
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
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)testBasic
{
    COPersistentRootInfo *info = [store createPersistentRootWithInitialItemGraph: [self itemGraphWithLabel: @"1"]
                                                                            UUID: persistentRootUUID
                                                                      branchUUID: branchAUUID
                                                                revisionMetadata: nil
                                                                           error: NULL];
    UKNotNil(info);
    
    
}

@end

