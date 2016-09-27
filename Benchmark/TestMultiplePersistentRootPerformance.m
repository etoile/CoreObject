#import "TestCommon.h"

@interface TestMultiplePersistentRootPerformance : EditingContextTestCase <UKTest>
@end

@implementation TestMultiplePersistentRootPerformance

#define NUM_PERSISTENT_ROOTS 100

#define NUM_COMMITS_PER_EDITING_SESSION 40

#define NUM_EDITING_SESSIONS 40

- (NSArray *)commitPersistentRoots
{
    NSMutableArray *proots = [NSMutableArray new];
    for (int i = 0; i < NUM_PERSISTENT_ROOTS; i++)
    {
        [proots addObject: [ctx insertNewPersistentRootWithEntityName: @"OutlineItem"]];
    }
    [ctx commit];

    return proots;
}

- (void) commitSessionWithPersistentRoot: (COPersistentRoot *)proot
{
    for (int commit=0; commit < NUM_COMMITS_PER_EDITING_SESSION; commit++)
    {
        OutlineItem *item = [[OutlineItem alloc] initWithObjectGraphContext: proot.objectGraphContext];
        item.label = [NSString stringWithFormat: @"Commit %d", commit];
        [[proot.rootObject mutableArrayValueForKey: @"contents"] addObject: item];
        [proot commit];
    }
}

- (void) readBackPersistentRootsBefore: (NSArray *)proots
{
    for (int i = 0; i < NUM_PERSISTENT_ROOTS; i++)
    {
        [[proots[i] store] itemGraphForRevisionUUID: [proots[i] currentRevision].UUID
                                     persistentRoot: [proots[i] UUID]];
    }
}

- (void) readBackPersistentRootsAfter: (NSArray *)proots
{
    for (int i = 0; i < NUM_PERSISTENT_ROOTS; i++)
    {
        [[proots[i] store] itemGraphForRevisionUUID: [proots[i] currentRevision].UUID
                                     persistentRoot: [proots[i] UUID]];
    }
}

- (void) testMultiplePersistentRoots
{
    NSArray *proots = [self commitPersistentRoots];

    [self readBackPersistentRootsBefore: proots];
    
    for (int session=0; session < NUM_EDITING_SESSIONS; session++)
    {
        const int prootIndex = rand() % NUM_PERSISTENT_ROOTS;
        COPersistentRoot *proot = proots[prootIndex];
        
        [self commitSessionWithPersistentRoot: proot];
    }
    
    [self readBackPersistentRootsAfter: proots];
}

@end
