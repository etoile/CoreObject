#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COHistoryTrack.h"
#import "COContainer.h"
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
	
	COContainer *parent = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *child = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *subchild = [ctx1 insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	
	ETUUID *parentUUID = [parent UUID];
	ETUUID *childUUID = [child UUID];
	ETUUID *subchildUUID = [subchild UUID];
	
	[parent setValue: @"Shopping" forProperty: @"label"];
	[child setValue: @"Groceries" forProperty: @"label"];
	[subchild setValue: @"Pizza" forProperty: @"label"];
	[child addObject: subchild];
	[parent addObject: child];
	
	COContainer *parentCopy = [ctx2 insertObject: parent fromContext: ctx1];
	COContainer *childCopy = [ctx2 insertObject: child fromContext: ctx1];
	COContainer *subchildCopy = [ctx2 insertObject: subchild fromContext: ctx1];
	
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
