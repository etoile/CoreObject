#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestCustomTrack : TestCommon <UKTest>
@end

@implementation TestCustomTrack

- (id)init
{
	SUPERINIT;
    
    COUndoStackStore *uss = [[COUndoStackStore alloc] init];
    for (NSString *stack in A(@"test", @"setup"))
    {
        [uss clearStacksForName: stack];
    }
    [uss release];
    
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

/* The custom track uses the root object commit track to undo and redo, no 
selective undo is involved. */
- (void)testWithSingleRootObject
{
	/* First commit */

	COContainer *object = [[ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"] rootObject];
	[object setValue: @"Groceries" forProperty: @"label"];
    [ctx commitWithStackNamed: @"setup"];
    CORevision *firstRevision = [[[object persistentRoot] currentBranch] currentRevision];
    
	/* Second commit */

	[object setValue: @"Shopping List" forProperty: @"label"];
    [ctx commitWithStackNamed: @"test"];
    CORevision *secondRevision = [[[object persistentRoot] currentBranch] currentRevision];
    
	/* Third commit */

	[object setValue: @"Todo" forProperty: @"label"];
    [ctx commitWithStackNamed: @"test"];
    CORevision *thirdRevision = [[[object persistentRoot] currentBranch] currentRevision];
    
	/* First undo  (Todo -> Shopping List) */

	UKTrue([ctx canUndoForStackNamed: @"test"]);
	[ctx undoForStackNamed: @"test"];
    
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, [[object persistentRoot] revision]);

	/*  Second undo (Shopping List -> Groceries) */

    UKTrue([ctx canUndoForStackNamed: @"test"]);
	[ctx undoForStackNamed: @"test"];
	UKFalse([ctx canUndoForStackNamed: @"test"]);
    
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);
	UKObjectsEqual(firstRevision, [[object persistentRoot] revision]);

	/* First redo (Groceries -> Shopping List) */

	UKTrue([ctx canRedoForStackNamed: @"test"]);
	[ctx redoForStackNamed: @"test"];

	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
	UKObjectsEqual(secondRevision, [[object persistentRoot] revision]);

	/* Second redo (Shopping List -> Todo) */

	UKTrue([ctx canRedoForStackNamed: @"test"]);
	[ctx redoForStackNamed: @"test"];
	UKFalse([ctx canRedoForStackNamed: @"test"]);
    
	UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
	UKObjectsEqual(thirdRevision, [[object persistentRoot] revision]);
}

- (NSArray *)makeCommitsWithMultipleRootObjects
{
	/* First commit */

	COPersistentRoot *objectPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *object = [objectPersistentRoot rootObject];
	[object setValue: @"Groceries" forProperty: @"label"];

    [ctx commitWithStackNamed: @"test"];
    
	/* Second commit */

    COPersistentRoot *docPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"Anonymous.OutlineItem"];
	COContainer *doc = [docPersistentRoot rootObject];
	[doc setValue: @"Document" forProperty: @"label"];

	[ctx commitWithStackNamed: @"test"];

	/* Third commit (two revisions) */

	COContainer *para1 = [[doc objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para1 setValue: @"paragraph 1" forProperty: @"label"];
	[object setValue: @"Shopping List" forProperty: @"label"];

	[ctx commitWithStackNamed: @"test"];

	/* Fourth commit */

	[object setValue: @"Todo" forProperty: @"label"];

	[ctx commitWithStackNamed: @"test"];

	/* Fifth commit */

	COContainer *para2 = [[doc objectGraphContext] insertObjectWithEntityName: @"Anonymous.OutlineItem"];
	[para2 setValue: @"paragraph 2" forProperty: @"label"];
	[doc addObject: para1];
	[doc addObject: para2];

	[ctx commitWithStackNamed: @"test"];

	/* Sixth commit */

	[para1 setValue: @"paragraph with different contents" forProperty: @"label"];

	[ctx commitWithStackNamed: @"test"];

	return A(object, doc, para1, para2);
}

- (void)testWithMultipleRootObjects
{
	NSArray *objects = [self makeCommitsWithMultipleRootObjects];

	COContainer *object = [objects objectAtIndex: 0];
	COContainer *doc = [objects objectAtIndex: 1];
	COContainer *para1 = [objects objectAtIndex: 2];
	COContainer *para2 = [objects objectAtIndex: 3];

	/* Basic undo/redo check */

	[ctx undoForStackNamed: @"test"];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	
	[ctx redoForStackNamed: @"test"];
	UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);

	/* Sixth and fifth commit undone ('doc' revision) */

	[ctx undoForStackNamed: @"test"];
	[ctx undoForStackNamed: @"test"];
	UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
	// FIXME: UKNil([ctx objectWithUUID: [para2 UUID]]);
	UKTrue([[doc content] isEmpty]);

	/* Fourth commit undone ('object' revision) */

	[ctx undoForStackNamed: @"test"];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);

	/* Third commit undone (two revisions one on 'doc' and one on 'object') */

	[ctx undoForStackNamed: @"test"];
	// FIXME: UKNil([ctx objectWithUUID: [para1 UUID]]);

	[ctx undoForStackNamed: @"test"];
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

	/* Second commit undone ('doc' revision) */

	[ctx undoForStackNamed: @"test"];
	// FIXME: UKNil([ctx objectWithUUID: [doc UUID]]);
	
	/* First commit reached (root object 'object') */
#if 0    
	// Just check the object creation hasn't been undone
	UKNotNil([ctx objectWithUUID: [object UUID]]);
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

	/* Second commit redone */

	[ctx redoForStackNamed: @"test"];
	UKNotNil([ctx objectWithUUID: [doc UUID]]);
	UKObjectsNotSame(doc, [ctx objectWithUUID: [doc UUID]]);
	// Get the new restored root object instance
	doc = (COContainer *)[ctx objectWithUUID: [doc UUID]];
	UKStringsEqual(@"Document", [doc valueForProperty: @"label"]);

	/* Third commit redone (involve two revisions) */

	[ctx redoForStackNamed: @"test"];
	[ctx redoForStackNamed: @"test"];
	UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);

	/* Third commit undone (involve two revisions)  */

	[ctx undoForStackNamed: @"test"];
	[ctx undoForStackNamed: @"test"];
	UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

	/* Third commit redone (involve two revisions) */

	[ctx redoForStackNamed: @"test"];
	[ctx redoForStackNamed: @"test"];
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
#endif
}

- (void)testSelectiveUndo
{
	[self makeCommitsWithMultipleRootObjects];
}

@end
