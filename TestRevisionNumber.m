#import "TestCommon.h"
#import <CoreObject/COObject.h>
#import <UnitKit/UnitKit.h>

@interface TestRevisionNumber : TestCommon <UKTest>
@end

@implementation TestRevisionNumber

- (void)testBaseRevision
{
	COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
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
	UKNotNil([secondCommitRev baseRevision]);
	UKObjectsEqual(firstCommitRev, [secondCommitRev baseRevision]);
	
	// The first commit revision's base revision should be nil
	UKNil([firstCommitRev baseRevision]);
}

- (void)testNonLinearHistory
{
	// We want to test whether something like this works:
	//  1--2--3
	//      \
	//       4
	ETUUID *objectUUID;
	
	// 1
	COObject *obj = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
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
	UKObjectsEqual(secondCommitRev, [thirdCommitRev baseRevision]);

	// Load up 2 in another context
	COEditingContext *ctx2 = NewContext(store);
	COObject *obj2 = [ctx2 objectWithUUID: objectUUID atRevision: secondCommitRev];
	UKNotNil(obj2);
	UKObjectsEqual(@"Second Revision", [obj2 valueForProperty: @"label"]);
	
	// 4
	[obj2 setValue: @"Fourth Revision" forProperty: @"label"];
	[ctx2 commit];
	UKObjectsNotEqual(secondCommitRev, [obj2 revision]);
	UKObjectsNotEqual(thirdCommitRev, [obj2 revision]);
	UKObjectsEqual(secondCommitRev, [[obj2 revision] baseRevision]);
}
@end
