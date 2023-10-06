/*
    Copyright (C) 2011 Quentin Mathe, Eric Wasylishen

    Date:  October 2011
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface TestRevisionNumber : EditingContextTestCase <UKTest>
@end


@implementation TestRevisionNumber

- (void)testBaseRevision
{
    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];
    UKNotNil(persistentRoot.UUID);

    COObject *obj = persistentRoot.rootObject;
    UKNil(obj.revision);

    [ctx commit];

    CORevision *firstCommitRev = obj.revision;
    UKNotNil(firstCommitRev);

    [obj setValue: @"The hello world label!" forProperty: @"label"];
    UKObjectsEqual(firstCommitRev, obj.revision);

    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           CORevision *secondCommitRev = [testProot.rootObject revision];

           UKNotNil(secondCommitRev);
           UKObjectsNotEqual(firstCommitRev,
                             secondCommitRev);

           // The base revision should be equals to the first revision
           UKNotNil(secondCommitRev.parentRevision);
           UKObjectsEqual(firstCommitRev,
                          secondCommitRev.parentRevision);

           // The first commit revision's base revision should be nil
           UKNil(firstCommitRev.parentRevision);
       }];
}

- (void)testNonLinearHistory
{
    // We want to test whether something like this works:
    //  1--2--3
    //      \
    //       4
    __unused ETUUID *objectUUID;

    COPersistentRoot *persistentRoot = [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"];

    // 1
    COObject *obj = persistentRoot.rootObject;
    objectUUID = obj.UUID;
    UKNil(obj.revision);
    [ctx commit];
    CORevision *firstCommitRev = obj.revision;
    UKNotNil(firstCommitRev);

    // 2
    [obj setValue: @"Second Revision" forProperty: @"label"];
    UKObjectsEqual(firstCommitRev, obj.revision);
    [ctx commit];
    CORevision *secondCommitRev = obj.revision;

    // 3
    [obj setValue: @"Third Revision" forProperty: @"label"];
    [ctx commit];
    CORevision *thirdCommitRev = obj.revision;
    UKObjectsEqual(secondCommitRev, thirdCommitRev.parentRevision);

    // Check that we can read the state 3 in another context
    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           UKNotNil(testProot);

           COObject *testObj2 = [testProot loadedObjectForUUID: obj.UUID];
           UKNotNil(testObj2);
           UKObjectsEqual(@"Third Revision",
                          [testObj2 valueForKey: @"label"]);
       }];

    // Load up 2 in another context

    {
        COEditingContext *ctx2 = [COEditingContext contextWithURL: store.URL];
        COPersistentRoot *persistentRootInCtx2 = [ctx2 persistentRootForUUID: persistentRoot.UUID];
        persistentRootInCtx2.currentRevision = secondCommitRev;

        COObject *obj2 = [persistentRootInCtx2 loadedObjectForUUID: obj.UUID];
        UKNotNil(obj2);
        UKObjectsEqual(@"Second Revision", [obj2 valueForProperty: @"label"]);

        // 4
        [obj2 setValue: @"Fourth Revision" forProperty: @"label"];
        [ctx2 commit];
        UKObjectsNotEqual(secondCommitRev, obj2.revision);
        UKObjectsNotEqual(thirdCommitRev, obj2.revision);
        UKObjectsEqual(secondCommitRev, obj2.revision.parentRevision);
    }

    [self wait];

    // Check that we can read the state 4 in another context

    [self checkPersistentRootWithExistingAndNewContext: persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           COObject *testObj2 = [testProot loadedObjectForUUID: obj.UUID];
           UKNotNil(testObj2);
           UKObjectsEqual(@"Fourth Revision",
                          [testObj2 valueForKey: @"label"]);
       }];
}

@end
