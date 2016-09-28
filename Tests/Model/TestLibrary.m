/*
    Copyright (C) 2014 Eric Wasylishen
 
    Date:  April 2014
    License:  MIT  (see COPYING)
*/

#import "TestCommon.h"

@interface TestLibrary : EditingContextTestCase <UKTest>
@end


@implementation TestLibrary

/**
 * Trivial test that the 'identifier' property works as expected.
 *
 * It's a tricky case because COLibrary overrides the property which is declared in
 * COObject as readonly, and makes it readwrite.
 */
- (void)testIdentifierPersisted
{
    COLibrary *library = [ctx insertNewPersistentRootWithEntityName: @"COLibrary"].rootObject;
    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: library.persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           UKNil([testProot.rootObject identifier]);
       }];

    UKFalse(library.persistentRoot.hasChanges);
    library.identifier = @"hello";
    UKTrue(library.persistentRoot.hasChanges);
    [ctx commit];

    [self checkPersistentRootWithExistingAndNewContext: library.persistentRoot
                                               inBlock:
       ^(COEditingContext *testCtx,
         COPersistentRoot *testProot,
         COBranch *testBranch,
         BOOL isNewContext)
       {
           UKObjectsEqual(@"hello",
                          [testProot.rootObject identifier]);
       }];
}

@end
