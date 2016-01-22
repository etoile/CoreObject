/*
	Copyright (C) 2016 Quentin Mathe

	Date:  January 2016
	License:  MIT  (see COPYING)
 */

#import "TestCommon.h"

@interface NSString (RandomStringGeneration)
+ (NSString *)defaultAlphabet;
+ (NSString *)randomStringWithAlphabet: (NSString *)alphabet length: (NSUInteger)len;
+ (NSString *)randomString;
@end

@interface TestHistoryNavigationPerformance : EditingContextTestCase <UKTest>
{
	int commitCounter;
}

@end

@implementation TestHistoryNavigationPerformance

#define NUM_PERSISTENT_ROOTS 500

#define BIG_NUM_PERSISTENT_ROOTS 1000

#define NUM_TOUCHED_PERSISTENT_ROOTS_PER_COMMIT 3

#define NUM_COMMITS 100

- (NSArray *)commitPersistentRootsWithUndoTrack: (COUndoTrack *)track
                                     entityName: (NSString *)entityName
                                          count: (int)nbOfPersistentRoots
{
	commitCounter++;
	NSMutableArray *proots = [NSMutableArray new];
	
	for (int i = 0; i < nbOfPersistentRoots; i++)
	{
		[proots addObject: [ctx insertNewPersistentRootWithEntityName: entityName]];
	}
	[ctx commitWithUndoTrack: track];

	return proots;
}

- (void)commitSessionWithPersistentRoot: (COPersistentRoot *)proot onUndoTrack: (COUndoTrack *)track
{
	commitCounter++;

	for (int session = 0; session < NUM_TOUCHED_PERSISTENT_ROOTS_PER_COMMIT; session++)
	{
		COTag *tag = [ctx.persistentRoots.anyObject rootObject];
	
		tag.name = [NSString stringWithFormat: @"Commit %d", commitCounter];
		[proot.rootObject addObjects: @[tag]];
	}

	[ctx commitWithUndoTrack: track];
}

- (void)testGoToOldestAndNewestNodesInHistory
{
	COUndoTrack *track = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                            withEditingContext: ctx];
	
	NSDate *startDate = [NSDate date];
	NSArray *proots = [self commitPersistentRootsWithUndoTrack: track
	                                                entityName: @"COTag"
	                                                     count: NUM_PERSISTENT_ROOTS];

	
	NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to commit %d new persistent roots with undo track: %0.2fs", NUM_PERSISTENT_ROOTS, creationTime);
	startDate = [NSDate date];

	for (int session = 0; session < NUM_COMMITS; session++)
	{
		const int prootIndex = rand() % NUM_PERSISTENT_ROOTS;
		COPersistentRoot *proot = proots[prootIndex];
		
		[self commitSessionWithPersistentRoot: proot onUndoTrack: track];
	}
	
	NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to make %d commits with undo track: %0.2fs", NUM_COMMITS, commitTime);
	startDate = [NSDate date];

	[track setCurrentNode: track.nodes.firstObject];
	
	NSTimeInterval goToFirstNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to newest node on undo track: %0.2fs", goToFirstNodeTime);
	startDate = [NSDate date];
	
	UKTrue(goToFirstNodeTime < 1.0); // FIXME: 0.5

	[track setCurrentNode: track.nodes.lastObject];
	
	NSTimeInterval goToLastNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to oldest node on undo track: %0.2fs", goToLastNodeTime);
	
	UKTrue(goToLastNodeTime < 1.0); // FIXME: 0.5
}

- (void)commitDeletionOfPersistentRoots: (NSArray *)prootSlice onUndoTrack: (COUndoTrack *)track
{
	commitCounter++;
	for (COPersistentRoot *proot in prootSlice)
	{
		proot.deleted = YES;
	}
	[ctx commitWithUndoTrack: track];
}

/**
 * Tests the cost associated with deleted persistent roots previously unloaded, 
 * that must be reloaded when navigating the history.
 *
 * A new editing context is created to ensure the revision cache is empty when
 * calling -[COUndoTrack setCurrentNode:].
 */
- (void)testGoToFirstCommitNodeToReloadManyDeletedPersistentRoots
{
	COUndoTrack *track = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                            withEditingContext: ctx];
	
	NSDate *startDate = [NSDate date];
	NSArray *proots = [self commitPersistentRootsWithUndoTrack: track
	                                                entityName: @"COTag"
	                                                     count: BIG_NUM_PERSISTENT_ROOTS];
	
	NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to commit %d new persistent roots with undo track: %0.2fs", BIG_NUM_PERSISTENT_ROOTS, creationTime);
	startDate = [NSDate date];

	for (int session = 0; session < NUM_COMMITS; session++)
	{
		NSUInteger sliceCount = BIG_NUM_PERSISTENT_ROOTS / NUM_COMMITS;
		NSUInteger splitIndex = proots.count - sliceCount;
		NSArray *prootSlice = [proots subarrayFromIndex: splitIndex];
		
		proots = [proots subarrayWithRange: NSMakeRange(0, splitIndex)];
		
		ETAssert(prootSlice.count == sliceCount);
		ETAssert(proots.count % sliceCount == 0);
		
		[self commitDeletionOfPersistentRoots: prootSlice onUndoTrack: track];
	}
	
	UKTrue(ctx.loadedPersistentRoots.isEmpty);
	
	NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to make %d commits with undo track: %0.2fs", NUM_COMMITS, commitTime);

	COEditingContext *ctx2 = [self newContext];
	COUndoTrack *track2 = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                             withEditingContext: ctx2];
	
	// Destroy the context to prevent it to catch any distributed notifications
	ctx = nil;
	startDate = [NSDate date];
	
	UKTrue(ctx2.loadedPersistentRoots.isEmpty);

	[track2 setCurrentNode: track2.nodes[1]];
	
	UKIntsEqual(BIG_NUM_PERSISTENT_ROOTS, ctx2.loadedPersistentRoots.count);
	
	NSTimeInterval goToNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to first commit node on undo track: %0.2fs", goToNodeTime);
	startDate = [NSDate date];
	
	UKTrue(goToNodeTime < 3.0); // FIXME: 1.0
}
- (void)updatePerson: (Person *)person includesNewStudents: (BOOL)includesNewStudents
{
	person.name = [NSString randomString];
	person.role = [NSString randomString];
	person.summary = [NSString randomStringWithAlphabet: [NSString defaultAlphabet] length: 100];
	person.age = arc4random() % 100;
	person.iconData = [[NSString randomString] dataUsingEncoding: NSUTF8StringEncoding];
	
	person.streetAddress = [NSString randomString];
	person.city = [NSString randomString];
	person.administrativeArea = [NSString randomString];
	person.postalCode = [NSString randomString];
	person.country = [NSString randomString];

	person.phoneNumber = [NSString randomStringWithAlphabet: @"0123456789" length: 10];
	person.emailAddress = [NSString randomString];
	person.website = [NSURL URLWithString: [NSString stringWithFormat: @"http://www.%@.com", [NSString randomString]]];
	
	if (!includesNewStudents)
		return;

	NSMutableSet *students = [NSMutableSet set];

	for (int i = 0; i < 15; i++)
	{
		Person *student = [[Person alloc] initWithObjectGraphContext: person.objectGraphContext];

		[self updatePerson: student includesNewStudents: NO];
		[students addObject: student];
	}
	person.students = students;
}

- (void)commitSessionWithPersons: (NSArray *)proots onUndoTrack: (COUndoTrack *)track
{
	commitCounter++;

	for (int session = 0; session < NUM_PERSISTENT_ROOTS / NUM_COMMITS; session++)
	{
		Person *person = (Person *)[proots[arc4random_uniform(proots.count)] rootObject];

		[self updatePerson: person includesNewStudents: YES];
	}

	[ctx commitWithUndoTrack: track];
}

- (void)testGoToOldestAndNewestNodesInHistoryWithManyPropertiesPerEntity
{
	COUndoTrack *track = [COUndoTrack trackForName: @"TestHistoryNavigationPerformance"
	                            withEditingContext: ctx];
	
	NSDate *startDate = [NSDate date];
	NSArray *proots = [self commitPersistentRootsWithUndoTrack: track
	                                                entityName: @"Person"
	                                                     count: NUM_PERSISTENT_ROOTS];

	
	NSTimeInterval creationTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to commit %d new persistent roots with undo track: %0.2fs", NUM_PERSISTENT_ROOTS, creationTime);
	startDate = [NSDate date];

	for (int session = 0; session < NUM_COMMITS; session++)
	{
		[self commitSessionWithPersons: proots onUndoTrack: track];
	}
	
	NSTimeInterval commitTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to make %d commits with undo track: %0.2fs", NUM_COMMITS, commitTime);
	startDate = [NSDate date];

	[track setCurrentNode: track.nodes.firstObject];
	
	NSTimeInterval goToFirstNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to oldest node on undo track: %0.2fs", goToFirstNodeTime);
	startDate = [NSDate date];
	
	UKTrue(goToFirstNodeTime < 3.0); // FIXME: 0.5

	[track setCurrentNode: track.nodes.lastObject];
	
	NSTimeInterval goToLastNodeTime = [[NSDate date] timeIntervalSinceDate: startDate];
	NSLog(@"Time to go to newest node on undo track: %0.2fs", goToLastNodeTime);
	
	UKTrue(goToLastNodeTime < 5.0); // FIXME: 0.5
}

@end


@implementation NSString (RandomStringGeneration)

+ (NSString *)defaultAlphabet
{
    return @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
}

+ (id)randomString
{
    return [self randomStringWithAlphabet: [self defaultAlphabet] length: 25];
}

+ (id)randomStringWithAlphabet: (NSString *)alphabet length: (NSUInteger)len
{
    NSMutableString *string = [NSMutableString stringWithCapacity: len];
	
    for (NSUInteger i = 0; i < len; i++)
	{
        u_int32_t r = arc4random() % alphabet.length;

        [string appendFormat: @"%C", [alphabet characterAtIndex: r]];
    }

    return [string copy];
}

@end
