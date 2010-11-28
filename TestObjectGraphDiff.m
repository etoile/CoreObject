#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COGroup.h"
#import "COCollection.h"
#import "TestCommon.h"

@interface TestObjectGraphDiff : NSObject <UKTest>
{
}
@end

@implementation TestObjectGraphDiff

- (void)testBasic
{
	COEditingContext *ctx1 = [[COEditingContext alloc] init];
	COEditingContext *ctx2 = [[COEditingContext alloc] init];
	
	COGroup *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COGroup *subchild = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	ETUUID *parentUUID = [parent UUID];
	ETUUID *childUUID = [child UUID];
	ETUUID *subchildUUID = [subchild UUID];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild setValue: @"Pizza" forProperty: @"label"];
	[child addObject: subchild];
	[parent addObject: child];
	
	COGroup *parentCopy = [ctx2 insertObject: parent fromContext: ctx1];
	COGroup *childCopy = [ctx2 insertObject: child fromContext: ctx1];
	COGroup *subchildCopy = [ctx2 insertObject: subchild fromContext: ctx1];
	
	// Now make some modifications to ctx2: 
	
	
	

	[ctx2 release];
	[ctx1 release];
}

- (void)testMove
{
	
}

- (void)testSimpleNonconflictingMerge
{
	
}

- (void)testComplexNonconflictingMerge
{
	
}

- (void)testSimpleConflictingMerge
{
	
}

- (void)testComplexConflictingMerge
{
	
}

- (void)testConflictingMovesMerge
{
	
}


@end
