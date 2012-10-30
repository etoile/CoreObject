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
	COCustomTrack *track;
}

@end

@implementation TestCustomTrack

- (id)init
{
	SUPERINIT;
	track = [[COCustomTrack alloc] initWithUUID: [ETUUID UUID] editingContext: ctx];
	return self;
}

- (void)dealloc
{
	DESTROY(track);
	[super dealloc];
}

- (void)testCreateWithNoRevisionsInStore
{
	UKNotNil(track);
	UKNil([track currentNode]);
	UKRaisesException([track undo]);
	UKRaisesException([track redo]);
}

- (COTrackNode *)pushAndCheckRevisionOnTrack: (CORevision *)rev 
                                previousNode: (COTrackNode *)previousNode 
{
	[track addRevisions: A(rev)];
	COTrackNode *currentNode = [track currentNode];

	UKNotNil(currentNode);
	UKObjectsSame(previousNode, [currentNode previousNode]);
	UKNil([currentNode nextNode]);
	UKObjectsEqual([currentNode revision], rev);

	if (previousNode == nil)
		return currentNode;

	UKObjectsSame(currentNode, [previousNode nextNode]);

	BOOL wasSameRootObjectForPreviousCommit = [[rev objectUUID] isEqual: [[previousNode revision] objectUUID]];
	
	if (wasSameRootObjectForPreviousCommit)
	{
		UKObjectsEqual([previousNode revision], [rev baseRevision]);
	}
	else
	{
		// TODO: Perhaps implement a check based on the object commit track
		UKObjectsNotEqual([previousNode revision], [rev baseRevision]);
	}

	return currentNode;
}

- (COTrackNode *)pushAndCheckRevisionsOnTrack: (NSArray *)revs 
                                 previousNode: (COTrackNode *)previousNode 
{
	COTrackNode *node = previousNode;

	for (CORevision *rev in revs)
	{
		node = [self pushAndCheckRevisionOnTrack: rev previousNode: node];
	}
	return node;
}

#if 0
/* The custom track uses the root object commit track to undo and redo, no 
selective undo is involved. */
- (void)testWithSingleRootObject
{
	/* First commit */

	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];

	COTrackNode *firstNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                               previousNode: nil];

	/* Second commit */

	[object setValue: @"Shopping List" forProperty: @"label"];

	COTrackNode *secondNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                                previousNode: firstNode];

	/* Third commit */

	[object setValue: @"Todo" forProperty: @"label"];

	COTrackNode *thirdNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                               previousNode: secondNode];

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
}

- (NSArray *)makeCommitsWithMultipleRootObjects
{
	/* First commit */

	COContainer *object = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[object setValue: @"Groceries" forProperty: @"label"];

	COTrackNode *firstNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                               previousNode: nil];

	/* Second commit */

	COContainer *doc = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[doc setValue: @"Document" forProperty: @"label"];

	COTrackNode *secondNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                                previousNode: firstNode];

	/* Third commit (two revisions) */

	COContainer *para1 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: doc];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	[object setValue: @"Shopping List" forProperty: @"label"];

	COTrackNode *thirdNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                               previousNode: secondNode];

	/* Fourth commit */

	[object setValue: @"Todo" forProperty: @"label"];

	COTrackNode *fourthNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                                previousNode: thirdNode];

	/* Fifth commit */

	COContainer *para2 = [ctx insertObjectWithEntityName: @"Anonymous.OutlineItem" rootObject: doc];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[doc addObject: para1];
	[doc addObject: para2];

	COTrackNode *fifthNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                               previousNode: fourthNode];

	/* Sixth commit */

	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];

	COTrackNode *sixthNode = [self pushAndCheckRevisionsOnTrack: [ctx commit] 
	                                               previousNode: fifthNode];

	return A(object, doc, para1, para2);
}

- (void)testWithMultipleRootObjects
{
	NSArray *objects = [self makeCommitsWithMultipleRootObjects];
	NSArray *nodes = [track cachedNodes];

	COContainer *object = [objects objectAtIndex: 0];
	COContainer *doc = [objects objectAtIndex: 1];
	COContainer *para1 = [objects objectAtIndex: 2];
	COContainer *para2 = [objects objectAtIndex: 3];

	/* Basic undo/redo check */

	[track undo];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
	[track redo];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);

	/* Sixth and fifth commit undone ('doc' revision) */

	[track undo];
	[track undo];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	// FIXME: UKNil([ctx objectWithUUID: [para2 UUID]]);
	UKTrue([[doc content] isEmpty]);

	/* Fourth commit undone ('object' revision) */

	[track undo];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);

	/* Third commit undone (two revisions one on 'doc' and one on 'object') */

	[track undo];
	// FIXME: UKNil([ctx objectWithUUID: [para1 UUID]]);

	[track undo];
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

	/* Second commit undone ('doc' revision) */

	[track undo];
	// FIXME: UKNil([ctx objectWithUUID: [doc UUID]]);
	
	/* First commit reached (root object 'object') */

	// Just check the object creation hasn't been undone
	UKNotNil([ctx objectWithUUID: [object UUID]]);
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

	/* Second commit redone */

	[track redo];
	UKNotNil([ctx objectWithUUID: [doc UUID]]);
	UKObjectsNotSame(doc, [ctx objectWithUUID: [doc UUID]]);
	// Get the new restored root object instance
	doc = (COContainer *)[ctx objectWithUUID: [doc UUID]];
	UKStringsEqual(@"Document", [doc valueForProperty: @"label"]);

	/* Third commit redone (involve two revisions) */

	[track redo];
	[track redo];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);

	/* Third commit undone (involve two revisions)  */

	[track undo];
	[track undo];
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

	/* Third commit redone (involve two revisions) */

	[track redo];
	[track redo];
	UKNotNil([ctx objectWithUUID: [para1 UUID]]);
	UKObjectsNotSame(para1, [ctx objectWithUUID: [para1 UUID]]);

	// Get the new restored object instance
	para1 = (COContainer *)[ctx objectWithUUID: [para1 UUID]];
	UKTrue([[doc allInnerObjectsIncludingSelf] containsObject: para1]);
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);

	/* Fourth, fifth and sixth commits redone */

	[track redo];
	[track redo];
	[track redo];
	UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
	UKNotNil([ctx objectWithUUID: [para2 UUID]]);
	UKObjectsNotSame(para2, [ctx objectWithUUID: [para2 UUID]]);

	// Get the new restored object instance
	para2 = (COContainer *)[ctx objectWithUUID: [para2 UUID]];
	UKTrue([[doc allInnerObjectsIncludingSelf] containsObject: para2]);
	UKStringsEqual(@"paragraph 2", [para2 valueForProperty: @"label"]);
	UKObjectsEqual(A(para1, para2), [doc content]);
}

- (void)testSelectiveUndo
{
	[self makeCommitsWithMultipleRootObjects];
}
#endif

@end
