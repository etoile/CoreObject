#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"
#import "COCustomTrack.h"
#import "COEditingContext.h"
#import "COObject.h"
#import "COContainer.h"

@interface TestCustomTrack : TestCommon <UKTest>
{

}

@end

@implementation TestCustomTrack

- (void)testCreateCustomTrackWithNoRevisionsInStore
{
	OPEN_STORE(store);
	COEditingContext *ctxt = NewContext(store);
	COCustomTrack *track = [COCustomTrack trackWithUUID: [ETUUID UUID] editingContext: ctxt];

	UKNotNil(track);
	UKNil([track currentNode]);
	UKRaisesException([track undo]);
	UKRaisesException([track redo]);

	TearDownContext(ctxt);
	CLOSE_STORE(store);
}

/* The custom track uses the root object commit track to undo and redo, no 
selective undo is involved. */
- (void)testWithSingleRootObject
{
	OPEN_STORE(store);
	COEditingContext *ctxt = NewContext(store);
	COCustomTrack *track = [COCustomTrack trackWithUUID: [ETUUID UUID] editingContext: ctxt];

	/* First commit */

	COContainer *object = [ctxt insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];
	[ctxt commit];

	CORevision *rev = [store revisionWithRevisionNumber: [store latestRevisionNumber]];
	[track addRevisions: A(rev)];
	COTrackNode *firstNode = [track currentNode];

	UKNotNil(firstNode);
	UKNil([firstNode previousNode]);
	UKNil([firstNode nextNode]);
	UKObjectsEqual([firstNode revision], rev);

	/* Second commit */

	[object setValue: @"Shopping List" forProperty: @"label"];
	[ctxt commit];

	rev = [store revisionWithRevisionNumber: [store latestRevisionNumber]];
	[track addRevisions: A(rev)];
	COTrackNode *secondNode = [track currentNode];

	UKNotNil(secondNode);
	UKObjectsEqual(firstNode, [secondNode previousNode]);
	UKNil([secondNode nextNode]);
	UKObjectsEqual(secondNode, [firstNode nextNode]);
	UKObjectsEqual([secondNode revision], rev);
	UKObjectsEqual([firstNode revision], [[secondNode revision] baseRevision]);

	/* Third commit */

	[object setValue: @"Todo" forProperty: @"label"];
	[ctxt commit];

	rev = [store revisionWithRevisionNumber: [store latestRevisionNumber]];
	[track addRevisions: A(rev)];
	COTrackNode *thirdNode = [track currentNode];

	UKNotNil(thirdNode);
	UKObjectsEqual(secondNode, [thirdNode previousNode]);
	UKNil([thirdNode nextNode]);
	UKObjectsEqual(thirdNode, [secondNode nextNode]);
	UKObjectsEqual([thirdNode revision], rev);
	UKObjectsEqual([[thirdNode revision] baseRevision], [secondNode revision]);

	/* First undo  (Todo -> Shopping List) */

	[track undo];

	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondNode, [track currentNode]);
	UKObjectsEqual([object revision], [[track currentNode] revision]);

	/*  Second undo (Shopping List -> Groceries) */

	[track undo];

	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);
	UKObjectsEqual(firstNode, [track currentNode]);
	UKObjectsEqual([object revision], [[track currentNode] revision]);

	[track undo];

	UKObjectsEqual(firstNode, [track currentNode]);

	/* First redo (Groceries -> Shopping List) */

	[track redo];

	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondNode, [track currentNode]);
	UKObjectsEqual([object revision], [[track currentNode] revision]);

	/* Second redo (Shopping List -> Todo) */

	[track redo];

	UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
	UKObjectsEqual(thirdNode, [track currentNode]);
	UKObjectsEqual([object revision], [[track currentNode] revision]);

	[track redo];

	UKObjectsEqual(thirdNode, [track currentNode]);

	TearDownContext(ctxt);
	CLOSE_STORE(store);
}

- (void)testWithMultipleRootObjects
{

}

- (void)testSelectiveUndo
{

}

@end
