#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COCommitTrack.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"

@interface TestCommitTrack : TestCommon <UKTest>
- (void)testNoExistingCommitTrack;
- (void)testSimpleRootObjectPropertyUndoRedo;
- (void)testWithObjectPropertiesUndoRedo;
@end

@implementation TestCommitTrack

- (void)testNoExistingCommitTrack
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];
	
	COCommitTrack *commitTrack = [object commitTrack];
	UKNotNil(commitTrack);
	UKNil([commitTrack currentNode]);

	[ctx commit];

	UKNotNil([commitTrack currentNode]);
	UKObjectsEqual([[commitTrack currentNode] revision], [object revision]);
}

- (void)testSimpleRootObjectPropertyUndoRedo
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];
	[ctx commit];
	
	COCommitTrack *commitTrack = [object commitTrack];
	COTrackNode *firstNode = [commitTrack currentNode];
	UKNotNil(commitTrack);
	UKNotNil(firstNode);
	UKFalse([commitTrack canUndo]);

	[object setValue: @"Shopping List" forProperty: @"label"];
	[ctx commit];
	COTrackNode *secondNode = [commitTrack currentNode];

	UKObjectsNotEqual(firstNode, secondNode);
	UKObjectsEqual([firstNode revision], [[secondNode revision] baseRevision]);

	[object setValue: @"Todo" forProperty: @"label"];
	[ctx commit];
	COTrackNode *thirdNode = [commitTrack currentNode];
	UKObjectsNotEqual(thirdNode, secondNode);
	UKObjectsEqual([[thirdNode revision] baseRevision], [secondNode revision]);

	// First undo (Todo -> Shopping List)
	[commitTrack undo];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondNode, [commitTrack currentNode]);

	// Second undo (Shopping List -> Groceries)
	[commitTrack undo];
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);
	UKObjectsEqual(firstNode, [commitTrack currentNode]);

	UKFalse([commitTrack canUndo]);

	// First redo (Groceries -> Shopping List)
	[commitTrack redo];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondNode, [commitTrack currentNode]);

	[commitTrack redo];
	UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
	UKObjectsEqual(thirdNode, [commitTrack currentNode]);

	UKFalse([commitTrack canRedo]);
}

/**
 * Test a root object with sub-object's connected as properties.
 */
- (void)testWithObjectPropertiesUndoRedo
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Document" forProperty: @"label"];
	[ctx commit];

	COContainer *para1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: object];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: object];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[object addObject: para1];
	[object addObject: para2];
	[ctx commit];

	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];
	[ctx commit];

	[[object commitTrack] undo];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
	[[object commitTrack] redo];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
}

- (void)testDivergentCommitTrack
{
	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Document" forProperty: @"label"];
	[ctx commit]; // Revision 1

	COContainer *para1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: object];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	COContainer *para2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: object];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[object addObject: para1];
	[object addObject: para2];
	UKIntsEqual(2, [object count]);
	[ctx commit]; // Revision 2 (base 1)

	[[object commitTrack] undo]; // back to Revision 1
	UKIntsEqual(0, [object count]);

	COContainer *para3 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: object];
	[para3 setValue: @"paragraph 3" forProperty: @"label"];
	[object addObject: para3];
	[ctx commit];
	UKIntsEqual(1, [object count]); // Revision 3 (base 1)

	[[object commitTrack] undo];
	UKIntsEqual(0, [object count]);

	[[object commitTrack] redo];
	UKIntsEqual(1, [object count]);
	UKStringsEqual(@"paragraph 3", [[[object contentArray] objectAtIndex: 0] valueForProperty: @"label"]);

	//UKIntsEqual(0, [para3 retainCount]);
}

@end
