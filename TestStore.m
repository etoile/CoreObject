#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COStore.h"
#import "TestCommon.h"

@interface TestStore : TestCommon <UKTest>
@end


@implementation TestStore

- (void)testCreate
{
	UKNotNil(store);
	UKIntsEqual(0, [store latestRevisionNumber]);
}

- (void)testReopenStore
{
	ETUUID *o1 = [ETUUID UUID];
	NSDictionary *sampleMetadata = D([NSNumber numberWithBool: YES], @"metadataWorks");
	
	[store insertRootObjectUUIDs: S(o1)];
	[store beginCommitWithMetadata: sampleMetadata rootObjectUUID: o1 baseRevision: nil];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"bob"
	    forProperty: @"name"
	       ofObject: o1
	    shouldIndex: NO];
	[store finishChangesForObjectUUID: o1];

	CORevision *c1 = [store finishCommit];
	int64_t revisionNumber = [c1 revisionNumber];		

	[self instantiateNewContextAndStore];

	c1 = [store revisionWithRevisionNumber: revisionNumber];
	
	UKNotNil(c1);
	UKIntsEqual(revisionNumber, [store latestRevisionNumber]);
	
	UKIntsEqual(1, [[c1 changedObjectUUIDs] count]);
	if ([[c1 changedObjectUUIDs] count] == 1)
	{
		UKObjectsEqual(o1, [[c1 changedObjectUUIDs] objectAtIndex: 0]);
	}

	UKObjectsEqual([NSNumber numberWithBool: YES], [[c1 metadata] objectForKey: @"metadataWorks"]);
	UKObjectsEqual(D(@"bob", @"name"), [c1 valuesAndPropertiesForObjectUUID: o1]);
}


- (void)testFullTextSearch
{
	ETUUID *o1 = [ETUUID UUID];

	[store insertRootObjectUUIDs: S(o1)];	
	
	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: nil];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"cats" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c1 = [store finishCommit];

	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: c1];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"dogs" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c2 = [store finishCommit];
	
	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: c2];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"horses" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c3 = [store finishCommit];
	
	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: c3];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"dogpound" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c4 = [store finishCommit];
	
	UKNotNil(c1);
	UKNotNil(c2);
	UKNotNil(c3);
	UKNotNil(c4);
	
	NSArray *searchResults = [store resultDictionariesForQuery: @"dog*"];
	UKIntsEqual(2, [searchResults count]);

	if ([searchResults count] == 2)
	{
		NSDictionary *result1 = [searchResults objectAtIndex: 0];
		NSDictionary *result2 = [searchResults objectAtIndex: 1];
		if ([c4 revisionNumber] == [[result1 objectForKey: @"revisionNumber"] unsignedLongLongValue])
		{
			id temp = result2; result2 = result1; result1 = temp;
		}
		UKObjectsEqual([NSNumber numberWithUnsignedLongLong: [c2 revisionNumber]], [result1 objectForKey: @"revisionNumber"]);
		UKObjectsEqual(o1, [result1 objectForKey: @"objectUUID"]);
		UKObjectsEqual(@"name", [result1 objectForKey: @"property"]);
		UKObjectsEqual(@"dogs", [result1 objectForKey: @"value"]);
		

		UKObjectsEqual([NSNumber numberWithUnsignedLongLong: [c4 revisionNumber]], [result2 objectForKey: @"revisionNumber"]);
		UKObjectsEqual(o1, [result2 objectForKey: @"objectUUID"]);
		UKObjectsEqual(@"name", [result2 objectForKey: @"property"]);
		UKObjectsEqual(@"dogpound", [result2 objectForKey: @"value"]);
	}
}

- (void)testCommitWithNoChanges
{
	ETUUID *o1 = [ETUUID UUID];

	[store insertRootObjectUUIDs: S(o1)];	
	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: nil];
	[store beginChangesForObjectUUID: o1];
	[store finishChangesForObjectUUID: o1];
	CORevision *c1 = [store finishCommit];

	UKNotNil(c1);
	UKIntsEqual(1, [c1 revisionNumber]);
	UKIntsEqual(1, [store latestRevisionNumber]);
	UKTrue([store isRootObjectUUID: o1]);
	UKObjectsEqual(S(o1), [store rootObjectUUIDs]);
}

- (void)testRootObject
{
	ETUUID *o1 = [ETUUID UUID];
	ETUUID *o2 = [ETUUID UUID];
	ETUUID *o3 = [ETUUID UUID];

	[store insertRootObjectUUIDs: S(o1)];

	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: nil];

	[store beginChangesForObjectUUID: o2];
	[store setValue: @"cats" forProperty: @"name" ofObject: o2 shouldIndex: NO];
	[store finishChangesForObjectUUID: o2];

	[store beginChangesForObjectUUID: o3];
	[store setValue: @"dogs" forProperty: @"name" ofObject: o3 shouldIndex: NO];
	[store finishChangesForObjectUUID: o3];

	CORevision *c1 = [store finishCommit];

	UKNotNil(c1);
	UKTrue([store isRootObjectUUID: o1]);
	UKFalse([store isRootObjectUUID: o2]);
	UKFalse([store isRootObjectUUID: o3]);
	UKObjectsEqual(S(o1), [store rootObjectUUIDs]);
	UKObjectsEqual(S(o1, o2, o3), [store UUIDsForRootObjectUUID: o1]);
	UKObjectsEqual(o1, [store rootObjectUUIDForUUID: o1]);
	UKObjectsEqual(o1, [store rootObjectUUIDForUUID: o2]);
	UKObjectsEqual(o1, [store rootObjectUUIDForUUID: o3]);
}

- (void)testStoreNil
{
	ETUUID *o1 = [ETUUID UUID];

	[store insertRootObjectUUIDs: S(o1)];
	[store beginCommitWithMetadata: nil rootObjectUUID: o1 baseRevision: nil];
	[store beginChangesForObjectUUID: o1];
	[store setValue: nil
	    forProperty: @"name"
	       ofObject: o1
	    shouldIndex: NO];
	[store finishChangesForObjectUUID: o1];
	CORevision *c1 = [store finishCommit];

	UKNotNil(c1);
}

@end
