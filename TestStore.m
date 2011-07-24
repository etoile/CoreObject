#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "COStore.h"
#import "TestCommon.h"

@interface TestStore : NSObject <UKTest> {
	
}

@end


@implementation TestStore

static COStore *SetUpStore()
{
	if([[NSFileManager defaultManager] fileExistsAtPath: [STORE_URL path]])
	{
		BOOL removed = [[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL];
		assert(removed);
	}
	
	return [[COStore alloc] initWithURL: STORE_URL];
}

static void TearDownStore(COStore *s)
{
	assert(s != nil);
	NSURL *url = [[s URL] retain];
	[s release];
	[[NSFileManager defaultManager] removeItemAtPath: [url path] error: NULL];
}


- (void)testCreate
{
	COStore *s = SetUpStore();
	UKNotNil(s);
	TearDownStore(s);
}

- (void)testReopenStore
{
	ETUUID *o1 = [ETUUID UUID];
	NSDictionary *sampleMetadata = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool: YES] forKey:@"metadataWorks"];
	uint64_t revisionNumber = 0;
	
	{
		COStore *s = [[COStore alloc] initWithURL: STORE_URL];

		[s insertRootObjectUUIDs: S(o1)];		
		[s beginCommitWithMetadata: sampleMetadata rootObjectUUID: o1];
		[s beginChangesForObjectUUID: o1];
		[s setValue: @"bob"
		forProperty: @"name"
		   ofObject: o1
		shouldIndex: NO];
		[s finishChangesForObjectUUID: o1];
		CORevision *c1 = [s finishCommit];
		revisionNumber = [c1 revisionNumber];		
		[s release];
	}
	
	{
		COStore *s2 = [[COStore alloc] initWithURL: STORE_URL];

		CORevision *c1 = [s2 revisionWithRevisionNumber: revisionNumber];
		
		UKNotNil(c1);
		
		UKIntsEqual(1, [[c1 changedObjects] count]);
		if ([[c1 changedObjects] count] == 1)
		{
			UKObjectsEqual(o1, [[c1 changedObjects] objectAtIndex: 0]);
		}
		
		UKObjectsEqual(sampleMetadata, [c1 metadata]);
		UKObjectsEqual([NSDictionary dictionaryWithObject: @"bob" forKey: @"name"],
					   [c1 valuesAndPropertiesForObject: o1]);
		
		[s2 release];
	}
	
	[[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL];
}


- (void)testFullTextSearch
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];

	[s insertRootObjectUUIDs: S(o1)];	
	
	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o1];
	[s setValue: @"cats" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObjectUUID: o1];
	CORevision *c1 = [s finishCommit];

	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o1];
	[s setValue: @"dogs" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObjectUUID: o1];
	CORevision *c2 = [s finishCommit];
	
	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o1];
	[s setValue: @"horses" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObjectUUID: o1];
	CORevision *c3 = [s finishCommit];
	
	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o1];
	[s setValue: @"dogpound" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObjectUUID: o1];
	CORevision *c4 = [s finishCommit];
	
	UKNotNil(c1);
	UKNotNil(c2);
	UKNotNil(c3);
	UKNotNil(c4);
	
	NSArray *searchResults = [s resultDictionariesForQuery: @"dog*"];
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
	TearDownStore(s);
}

- (void)testCommitWithNoChanges
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];

	[s insertRootObjectUUIDs: S(o1)];	
	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o1];
	[s finishChangesForObjectUUID: o1];
	CORevision *c1 = [s finishCommit];
	UKNotNil(c1);
	UKTrue([s isRootObjectUUID: o1]);
	UKObjectsEqual(S(o1), [s rootObjectUUIDs]);

	TearDownStore(s);
}

- (void)testRootObject
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];
	ETUUID *o2 = [ETUUID UUID];
	ETUUID *o3 = [ETUUID UUID];
	[s insertRootObjectUUIDs: S(o1)];
	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o2];
	[s setValue: @"cats" forProperty: @"name" ofObject: o2 shouldIndex: NO];
	[s finishChangesForObjectUUID: o2];
	[s beginChangesForObjectUUID: o3];
	[s setValue: @"dogs" forProperty: @"name" ofObject: o3 shouldIndex: NO];
	[s finishChangesForObjectUUID: o3];
	CORevision *c1 = [s finishCommit];
	UKNotNil(c1);
	UKTrue([s isRootObjectUUID: o1]);
	UKFalse([s isRootObjectUUID: o2]);
	UKFalse([s isRootObjectUUID: o3]);
	UKObjectsEqual(S(o1), [s rootObjectUUIDs]);
	UKObjectsEqual(S(o1, o2, o3), [s UUIDsForRootObjectUUID: o1]);
	UKObjectsEqual(o1, [s rootObjectUUIDForUUID: o1]);
	UKObjectsEqual(o1, [s rootObjectUUIDForUUID: o2]);
	UKObjectsEqual(o1, [s rootObjectUUIDForUUID: o3]);

	TearDownStore(s);
}


- (void)testStoreNil
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];

	[s insertRootObjectUUIDs: S(o1)];	
	[s beginCommitWithMetadata: nil rootObjectUUID: o1];
	[s beginChangesForObjectUUID: o1];
	[s setValue: nil
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];
	[s finishChangesForObjectUUID: o1];
	CORevision *c1 = [s finishCommit];

	UKNotNil(c1);
	
	TearDownStore(s);
}

@end
