/*
    Copyright (C) 2024 Quentin Mathe

    Date:  January 2024
    License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface NSString (RandomStringGeneration)
+ (NSString *)defaultAlphabet;
+ (NSString *)randomStringWithAlphabet: (NSString *)alphabet length: (NSUInteger)len;
+ (NSString *)randomString;
@end


@interface TestRevisionRewritingPerformance : EditingContextTestCase <UKTest>
{
    int revCounter;
}

@end


@implementation TestRevisionRewritingPerformance

#define NUM_PERSISTENT_ROOTS 50
#define NUM_COMMITS 100

- (NSArray *)commitPersistentRootsWithEntityName: (NSString *)entityName
                                           count: (int)nbOfPersistentRoots
                                    studentCount: (int)studentCount
{
    NSMutableArray *proots = [NSMutableArray new];

    for (int i = 0; i < nbOfPersistentRoots; i++)
    {
        COPersistentRoot *proot = [ctx insertNewPersistentRootWithEntityName: entityName];
        [self addNewStudents: studentCount toPerson: proot.rootObject];
        [proots addObject: proot];
        revCounter++;
    }
    [ctx commit];

    return proots;
}

- (void)updatePerson: (Person *)person
{
    uint32_t draw = arc4random_uniform(3);
    
    switch (draw)
    {
        case 0:
            person.name = [NSString randomString];
            person.role = [NSString randomString];
            break;
        case 1:
            person.summary = [NSString randomStringWithAlphabet: [NSString defaultAlphabet] length: 100];
            person.age = arc4random() % 100;
            person.iconData = [[NSString randomString] dataUsingEncoding: NSUTF8StringEncoding];
            break;
        case 2:
            person.streetAddress = [NSString randomString];
            person.city = [NSString randomString];
            person.administrativeArea = [NSString randomString];
            person.postalCode = [NSString randomString];
            person.country = [NSString randomString];
            break;
        case 3:
            person.phoneNumber = [NSString randomStringWithAlphabet: @"0123456789" length: 10];
            person.emailAddress = [NSString randomString];
            person.website = [NSURL URLWithString: [NSString stringWithFormat: @"http://www.%@.com",
                                                                               [NSString randomString]]];
            break;
        default:
            break;
    }
}

- (void)addNewStudents: (int)count toPerson: (Person *)person
{
    if (count == 0)
    {
        return;
    }
    NSMutableSet *students = [person.students mutableCopy];

    for (int i = 0; i < count; i++)
    {
        Person *student = [[Person alloc] initWithObjectGraphContext: person.objectGraphContext];

        [self updatePerson: person];
        [students addObject: student];
    }
    person.students = students;
}

- (void)makeCommitToPersistentRoots: (NSArray *)proots studentCount: (NSInteger)count
{
    for (COPersistentRoot *proot in proots)
    {
        Person *person = (Person *)[proot rootObject];

        [self updatePerson: person];
        [self addNewStudents: count toPerson: person];

        revCounter++;
    }
    [ctx commit];
}

- (void)testSingleItem
{
    ctx.recordingUndo = NO;

    NSDate *startDate = [NSDate date];
    NSArray *proots = [self commitPersistentRootsWithEntityName: @"Person"
                                                          count: NUM_PERSISTENT_ROOTS
                                                   studentCount: 0];

    NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to commit %d new persistent roots: %0.2fs", NUM_PERSISTENT_ROOTS, creationTime);
    startDate = [NSDate date];

    for (int commit = 0; commit < (NUM_COMMITS - 1); commit++)
    {
        [self makeCommitToPersistentRoots: proots studentCount: 0];
    }

    NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to make %d commits: %0.2fs", (NUM_COMMITS - 1), commitTime);
    startDate = [NSDate date];
    
    NSInteger __block migrationCounter = 0;

    [ctx.store migrateRevisionsToVersion: 1
                             withHandler: ^COItemGraph *(COItemGraph *oldItemGraph, int64_t oldVersion, int64_t newVersion)
     {
        NSMutableArray *newItems = [NSMutableArray array];

        for (COItem *oldItem in oldItemGraph.items)
        {
            ETAssert(oldVersion == oldItem.packageVersion);
            COMutableItem *newItem = [oldItem mutableCopy];
            newItem.packageVersion = newVersion;
            [newItems addObject: newItem];
        }
        migrationCounter += 1;

        return [[COItemGraph alloc] initWithItems: newItems
                                     rootItemUUID: oldItemGraph.rootItemUUID];
    }];
    
    UKIntsEqual(NUM_PERSISTENT_ROOTS * NUM_COMMITS, revCounter);
    UKIntsEqual(revCounter, migrationCounter);

    const NSTimeInterval rewriteTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to rewrite %d store revisions: %0.2fs", revCounter, rewriteTime);
}

- (void)testFixedItemCount
{
    ctx.recordingUndo = NO;

    NSDate *startDate = [NSDate date];
    NSArray *proots = [self commitPersistentRootsWithEntityName: @"Person"
                                                          count: NUM_PERSISTENT_ROOTS
                                                   studentCount: 50];

    NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to commit %d new persistent roots: %0.2fs", NUM_PERSISTENT_ROOTS, creationTime);
    startDate = [NSDate date];

    for (int commit = 0; commit < (NUM_COMMITS - 1); commit++)
    {
        [self makeCommitToPersistentRoots: proots studentCount: 0];
    }

    NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to make %d commits: %0.2fs", (NUM_COMMITS - 1), commitTime);
    startDate = [NSDate date];
    
    NSInteger __block migrationCounter = 0;

    [ctx.store migrateRevisionsToVersion: 1
                             withHandler: ^COItemGraph *(COItemGraph *oldItemGraph, int64_t oldVersion, int64_t newVersion)
     {
        NSMutableArray *newItems = [NSMutableArray array];

        for (COItem *oldItem in oldItemGraph.items)
        {
            ETAssert(oldVersion == oldItem.packageVersion);
            COMutableItem *newItem = [oldItem mutableCopy];
            newItem.packageVersion = newVersion;
            [newItems addObject: newItem];
        }
        migrationCounter += 1;

        return [[COItemGraph alloc] initWithItems: newItems
                                     rootItemUUID: oldItemGraph.rootItemUUID];
    }];
    
    UKIntsEqual(NUM_PERSISTENT_ROOTS * NUM_COMMITS, revCounter);
    UKIntsEqual(revCounter, migrationCounter);

    const NSTimeInterval rewriteTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to rewrite %d store revisions: %0.2fs", revCounter, rewriteTime);
}

- (void)testGrowingItemCount
{
    ctx.recordingUndo = NO;

    NSDate *startDate = [NSDate date];
    NSArray *proots = [self commitPersistentRootsWithEntityName: @"Person"
                                                          count: NUM_PERSISTENT_ROOTS
                                                   studentCount: 0];

    NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to commit %d new persistent roots: %0.2fs", NUM_PERSISTENT_ROOTS, creationTime);
    startDate = [NSDate date];

    for (int commit = 0; commit < (NUM_COMMITS - 1); commit++)
    {
        [self makeCommitToPersistentRoots: proots studentCount: 1];
    }

    NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to make %d commits: %0.2fs", (NUM_COMMITS - 1), commitTime);
    startDate = [NSDate date];
    
    NSInteger __block migrationCounter = 0;

    [ctx.store migrateRevisionsToVersion: 1
                             withHandler: ^COItemGraph *(COItemGraph *oldItemGraph, int64_t oldVersion, int64_t newVersion)
     {
        NSMutableArray *newItems = [NSMutableArray array];

        for (COItem *oldItem in oldItemGraph.items)
        {
            ETAssert(oldVersion == oldItem.packageVersion);
            COMutableItem *newItem = [oldItem mutableCopy];
            newItem.packageVersion = newVersion;
            [newItems addObject: newItem];
        }
        migrationCounter += 1;

        return [[COItemGraph alloc] initWithItems: newItems
                                     rootItemUUID: oldItemGraph.rootItemUUID];
    }];
    
    UKIntsEqual(NUM_PERSISTENT_ROOTS * NUM_COMMITS, revCounter);
    UKIntsEqual(revCounter, migrationCounter);

    const NSTimeInterval rewriteTime = [[NSDate date] timeIntervalSinceDate: startDate];
    NSLog(@"Time to rewrite %d store revisions: %0.2fs", revCounter, rewriteTime);
}

@end
