#import "TestCommon.h"
#import <CoreObject/COObject.h>
#import <UnitKit/UnitKit.h>

@interface TestRevisionNumber : TestCommon <UKTest>
@end

@implementation TestRevisionNumber

- (void)testBaseRevision
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    UKNotNil([persistentRoot persistentRootUUID]);
    
	COObject *obj = [persistentRoot rootObject];
	UKNil([obj revision]);
	
	[ctx commit];
	
	CORevision *firstCommitRev = [obj revision];
	UKNotNil(firstCommitRev);
    
	[obj setValue: @"The hello world label!" forProperty: @"label"];
	UKObjectsEqual(firstCommitRev, [obj revision]);

	[ctx commit];

	CORevision *secondCommitRev = [obj revision];

	UKNotNil(secondCommitRev);
	UKObjectsNotEqual(firstCommitRev, secondCommitRev);
	
	// The base revision should be equals to the first revision
	UKNotNil([secondCommitRev parentRevision]);
	UKObjectsEqual(firstCommitRev, [secondCommitRev parentRevision]);
	
	// The first commit revision's base revision should be nil
	UKNil([firstCommitRev parentRevision]);
}

- (void)testNonLinearHistory
{
	// We want to test whether something like this works:
	//  1--2--3
	//      \
	//       4
	ETUUID *objectUUID;
	
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
    
	// 1
	COObject *obj = [persistentRoot rootObject];
	objectUUID = [obj UUID];
	UKNil([obj revision]);
	[ctx commit];
	CORevision *firstCommitRev = [obj revision];
	UKNotNil(firstCommitRev);
	
	// 2
	[obj setValue: @"Second Revision" forProperty: @"label"];
	UKObjectsEqual(firstCommitRev, [obj revision]);
	[ctx commit];
	CORevision *secondCommitRev = [obj revision];

	// 3
	[obj setValue: @"Third Revision" forProperty: @"label"];
	[ctx commit];
	CORevision *thirdCommitRev = [obj revision];
	UKObjectsEqual(secondCommitRev, [thirdCommitRev parentRevision]);

    // Check that we can read the state 3 in another context
    {
        COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: store];
        COPersistentRoot *persistentRootInCtx2 = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        UKNotNil(persistentRootInCtx2);
        
        COObject *obj2 = [persistentRootInCtx2 objectWithUUID: [obj UUID]];
        UKNotNil(obj2);
        UKObjectsEqual(@"Third Revision", [obj2 valueForKey: @"label"]);
        
        [ctx2 release];
    }
    
	// Load up 2 in another context
    
    {
        COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: store];
        COPersistentRoot *persistentRootInCtx2 = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];
        [persistentRootInCtx2 setRevision: secondCommitRev];
        
        COObject *obj2 = [persistentRootInCtx2 objectWithUUID: [obj UUID]];
        UKNotNil(obj2);
        UKObjectsEqual(@"Second Revision", [obj2 valueForProperty: @"label"]);
        
        // 4
        [obj2 setValue: @"Fourth Revision" forProperty: @"label"];
        [ctx2 commit];
        UKObjectsNotEqual(secondCommitRev, [obj2 revision]);
        UKObjectsNotEqual(thirdCommitRev, [obj2 revision]);
        UKObjectsEqual(secondCommitRev, [[obj2 revision] parentRevision]);
        
        [ctx2 release];
    }
    
    // Check that we can read the state 4 in another context
    {
        COEditingContext *ctx2 = [[COEditingContext alloc] initWithStore: store];
        COPersistentRoot *persistentRootInCtx2 = [ctx2 persistentRootForUUID: [persistentRoot persistentRootUUID]];

        COObject *obj2 = [persistentRootInCtx2 objectWithUUID: [obj UUID]];
        UKNotNil(obj2);
        UKObjectsEqual(@"Fourth Revision", [obj2 valueForKey: @"label"]);
        
        [ctx2 release];
    }
}
@end
