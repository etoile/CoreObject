/*
    Copyright (C) 2012 Quentin Mathe, Eric Wasylishen

    Date:  April 2012
    License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <EtoileFoundation/ETModelDescriptionRepository.h>
#import "TestCommon.h"

@interface TestCustomTrack : EditingContextTestCase <UKTest>
{
    COUndoTrack *_testTrack;
    COUndoTrack *_setupTrack;
}

@end


@implementation TestCustomTrack

- (id)init
{
    SUPERINIT;

    _testTrack = [COUndoTrack trackForName: @"test" withEditingContext: ctx];
    _setupTrack = [COUndoTrack trackForName: @"setup" withEditingContext: ctx];
    [_testTrack clear];
    [_setupTrack clear];

    return self;
}

/* The custom track uses the root object commit track to undo and redo, no 
selective undo is involved. */
- (void)testUndoWithSinglePersistentRoot
{
    /* First commit */

    COContainer *object = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"].rootObject;
    [object setValue: @"Groceries" forProperty: @"label"];
    [ctx commitWithUndoTrack: _setupTrack];
    CORevision *firstRevision = object.persistentRoot.currentBranch.currentRevision;

    /* Second commit */

    [object setValue: @"Shopping List" forProperty: @"label"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *secondRevision = object.persistentRoot.currentBranch.currentRevision;

    /* Third commit */

    [object setValue: @"Todo" forProperty: @"label"];
    [ctx commitWithUndoTrack: _testTrack];
    CORevision *thirdRevision = object.persistentRoot.currentBranch.currentRevision;

    /* First undo  (Todo -> Shopping List) */

    UKTrue(_testTrack.canUndo);
    [_testTrack undo];

    UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
    UKObjectsEqual(secondRevision, object.persistentRoot.currentRevision);

    /*  Second undo (Shopping List -> Groceries) */

    UKTrue(_testTrack.canUndo);
    [_testTrack undo];
    UKFalse(_testTrack.canUndo);

    UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);
    UKObjectsEqual(firstRevision, object.persistentRoot.currentRevision);

    /* First redo (Groceries -> Shopping List) */

    UKTrue(_testTrack.canRedo);
    [_testTrack redo];

    UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);
    UKObjectsEqual(secondRevision, object.persistentRoot.currentRevision);

    /* Second redo (Shopping List -> Todo) */

    UKTrue(_testTrack.canRedo);
    [_testTrack redo];
    UKFalse(_testTrack.canRedo);

    UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
    UKObjectsEqual(thirdRevision, object.persistentRoot.currentRevision);
}

- (NSArray *)makeCommitsWithMultiplePersistentRoots
{
    /*
                 commit #:    1   2   3   4   5   6
     
     objectPersistentRoot:    x-------x---x--------
     
        docPersistentRoot:        x---x-------x---x
     
     */


    /* First commit */

    COPersistentRoot *objectPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    COContainer *object = objectPersistentRoot.rootObject;
    [object setValue: @"Groceries" forProperty: @"label"];

    [ctx commitWithUndoTrack: _testTrack];

    /* Second commit */

    COPersistentRoot *docPersistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    COContainer *doc = docPersistentRoot.rootObject;
    [doc setValue: @"Document" forProperty: @"label"];

    [ctx commitWithUndoTrack: _testTrack];

    /* Third commit call (creates commits in objectPersistentRoot and docPersistentRoot) */

    COContainer *para1 = [doc.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    [para1 setValue: @"paragraph 1" forProperty: @"label"];
    [doc addObject: para1];
    [object setValue: @"Shopping List" forProperty: @"label"];

    [ctx commitWithUndoTrack: _testTrack];

    /* Fourth commit */

    [object setValue: @"Todo" forProperty: @"label"];

    [ctx commitWithUndoTrack: _testTrack];

    /* Fifth commit */

    COContainer *para2 = [doc.objectGraphContext insertObjectWithEntityName: @"OutlineItem"];
    [para2 setValue: @"paragraph 2" forProperty: @"label"];
    [doc addObject: para2];

    [ctx commitWithUndoTrack: _testTrack];

    /* Sixth commit */

    [para1 setValue: @"paragraph with different contents" forProperty: @"label"];

    [ctx commitWithUndoTrack: _testTrack];

    return @[object, doc, para1, para2];
}

- (void)testUndoWithMultiplePersistentRoots
{
    NSArray *objects = [self makeCommitsWithMultiplePersistentRoots];

    OutlineItem *object = objects[0];
    OutlineItem *doc = objects[1];
    OutlineItem *para1 = objects[2];
    OutlineItem *para2 = objects[3];

    COPersistentRoot *objectPersistentRoot = object.persistentRoot;
    UKNotNil(objectPersistentRoot);

    COPersistentRoot *docPersistentRoot = doc.persistentRoot;
    UKNotNil(docPersistentRoot);

    UKObjectsNotEqual(docPersistentRoot, objectPersistentRoot);

    /* Basic undo/redo check */

    [_testTrack undo];
    UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);

    [_testTrack redo];
    UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);

    /* Sixth and fifth commit undone ('doc' revision) */

    UKNotNil([docPersistentRoot loadedObjectForUUID: para2.UUID]);
    UKObjectsEqual((@[para1, para2]), doc.contents);
    [_testTrack undo];
    [_testTrack undo];
    UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);
    // i.e., check for garbage collection
    UKNil([docPersistentRoot loadedObjectForUUID: para2.UUID]);
    UKObjectsEqual(@[para1], doc.contents);

    /* Fourth commit undone ('object' revision) */

    [_testTrack undo];
    UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);

    /* Third commit call undone (two underlying commits, one on 'doc' and one on 'object') */

    UKNotNil([docPersistentRoot loadedObjectForUUID: para1.UUID]);
    [_testTrack undo];
    UKNil([docPersistentRoot loadedObjectForUUID: para1.UUID]);
    UKObjectsEqual(@[], doc.contents);
    UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

    /* Second commit undone ('doc' revision) */

    [_testTrack undo];
    UKTrue(docPersistentRoot.deleted);

    /***********************************************/
    /* First commit reached (root object 'object') */
    /***********************************************/

    // Just check the object creation hasn't been undone
    UKNotNil([objectPersistentRoot loadedObjectForUUID: object.UUID]);
    UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

    /* Second commit redone */

    [_testTrack redo];
    UKFalse(docPersistentRoot.deleted);
    UKNotNil([docPersistentRoot loadedObjectForUUID: doc.UUID]);
    UKObjectsSame(doc, [docPersistentRoot loadedObjectForUUID: doc.UUID]);
    UKStringsEqual(@"Document", [doc valueForProperty: @"label"]);

    /* Third commit redone (involve two underlying commits) */

    [_testTrack redo];
    UKStringsEqual(@"Shopping List", [object valueForProperty: @"label"]);

    /* Third commit undone (involve two underlying commits)  */

    [_testTrack undo];
    UKStringsEqual(@"Groceries", [object valueForProperty: @"label"]);

    /* Third commit redone (involve two underlying commits) */

    [_testTrack redo];
    UKNotNil([docPersistentRoot loadedObjectForUUID: para1.UUID]);
    UKObjectsNotSame(para1, [docPersistentRoot loadedObjectForUUID: para1.UUID]);

    // Get the new restored object instance
    para1 = (OutlineItem *)[docPersistentRoot loadedObjectForUUID: para1.UUID];
    UKObjectsEqual(@[para1], doc.contents);
    UKStringsEqual(@"paragraph 1", [para1 valueForProperty: @"label"]);

    /* Fourth, fifth and sixth commits redone */

    [_testTrack redo];
    [_testTrack redo];
    [_testTrack redo];
    UKFalse(_testTrack.canRedo);
    UKStringsEqual(@"Todo", [object valueForProperty: @"label"]);
    UKStringsEqual(@"paragraph with different contents", [para1 valueForProperty: @"label"]);
    UKNotNil([docPersistentRoot loadedObjectForUUID: para2.UUID]);
    UKObjectsNotSame(para2, [docPersistentRoot loadedObjectForUUID: para2.UUID]);

    // Get the new restored object instance
    para2 = (OutlineItem *)[docPersistentRoot loadedObjectForUUID: para2.UUID];
    UKObjectsEqual((@[para1, para2]), doc.contents);
    UKStringsEqual(@"paragraph 2", [para2 valueForProperty: @"label"]);
}

@end
