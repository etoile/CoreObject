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
	ETUUID *branchUUID;
	
	{
		COStore *s = [[COStore alloc] initWithURL: STORE_URL];
		
		CONamedBranch *b = [s createNamedBranch];
		branchUUID = [b UUID];
		[b setName: @"My Branch"];
		
		[s release];
	}
	
	{
		COStore *s2 = [[COStore alloc] initWithURL: STORE_URL];

		CONamedBranch *b2 = [s2 namedBranchForUUID: branchUUID];
		UKStringsEqual(@"My Branch", [b2 name]);	
		
		[s2 release];
	}
	
	[[NSFileManager defaultManager] removeItemAtPath: [STORE_URL path] error: NULL];
}

- (void)testNamedBranch
{
	COStore *s = SetUpStore();
	CONamedBranch *b = [s createNamedBranch];
	UKNotNil(b);
	
	[b setName: @"My Branch"];
	UKStringsEqual(@"My Branch", [b name]);
	
	UKObjectsEqual(b, [s namedBranchForUUID: [b UUID]]);
	
	[b setMetadata: [NSDictionary dictionaryWithObject:[NSNumber numberWithBool: YES] forKey:@"metadataWorks"]];
	UKObjectsEqual([NSNumber numberWithBool: YES], [[b metadata] objectForKey: @"metadataWorks"]);
	
	TearDownStore(s);
}

- (void)testComittingChanges
{
	COStore *s = SetUpStore();
	
	NSDictionary *sampleMetadata = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool: YES] forKey:@"metadataWorks"];
	ETUUID *o1 = [ETUUID UUID];
	
	
	[s beginCommitWithMetadata: sampleMetadata];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];
	[s setValue: @"bob"
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];
	
	UKNotNil(c1);
	
    UKIntsEqual(1, [[c1 changedObjects] count]);
	if ([[c1 changedObjects] count] == 1)
	{
		UKObjectsEqual(o1, [[c1 changedObjects] objectAtIndex: 0]);
	}
	
	UKObjectsEqual(sampleMetadata, [c1 metadata]);
	UKNil([c1 namedBranchForObject: o1]);
	UKNil([c1 parentCommitForObject: o1]);
	UKNil([c1 mergedCommitForObject: o1]);
	UKObjectsEqual([NSArray array], [c1 childCommitsForObject: o1]);
	UKObjectsEqual([NSDictionary dictionaryWithObject: @"bob" forKey: @"name"],
				   [c1 valuesAndPropertiesForObject: o1]);
	
	TearDownStore(s);
}

- (void)testFullTextSearch
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1 onNamedBranch: nil updateObjectState: YES parentCommit: nil mergedCommit: nil];
	[s setValue: @"cats" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];

	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1 onNamedBranch: nil updateObjectState: YES parentCommit: c1	mergedCommit: nil];
	[s setValue: @"dogs" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObject: o1];
	COCommit *c2 = [s finishCommit];
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1 onNamedBranch: nil updateObjectState: YES parentCommit: c2	mergedCommit: nil];
	[s setValue: @"horses" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObject: o1];
	COCommit *c3 = [s finishCommit];
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1 onNamedBranch: nil updateObjectState: YES parentCommit: c3	mergedCommit: nil];
	[s setValue: @"dogpound" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[s finishChangesForObject: o1];
	COCommit *c4 = [s finishCommit];
	
	NSArray *searchResults = [s resultDictionariesForQuery: @"dog*"];
	UKIntsEqual(2, [searchResults count]);
	if ([searchResults count] == 2)
	{
		NSDictionary *result1 = [searchResults objectAtIndex: 0];
		NSDictionary *result2 = [searchResults objectAtIndex: 1];
		if ([[c4 UUID] isEqual: [result1 objectForKey: @"commitUUID"]])
		{
			id temp = result2; result2 = result1; result1 = temp;
		}
		UKObjectsEqual([c2 UUID], [result1 objectForKey: @"commitUUID"]);
		UKObjectsEqual(o1, [result1 objectForKey: @"objectUUID"]);
		UKObjectsEqual(@"name", [result1 objectForKey: @"property"]);
		UKObjectsEqual(@"dogs", [result1 objectForKey: @"value"]);
		

		UKObjectsEqual([c4 UUID], [result2 objectForKey: @"commitUUID"]);
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
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];	
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];
	UKNotNil(c1);
	
	TearDownStore(s);
}

- (void)testHistoryGraphBasic
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];	
	[s setValue: @"bob"
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];	
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: c1
				mergedCommit: nil];
	[s setValue: @"bob"
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];	
	[s finishChangesForObject: o1];
	COCommit *c2 = [s finishCommit];
	
	COCommit *c = [c2 parentCommitForObject: o1];
	COCommit *csame = [c2 parentCommitForObject: o1];
	UKNotNil(c);
	UKObjectsEqual(c1, c);
	UKObjectsEqual(c, csame);
	
	TearDownStore(s);
}

- (void)testObjectState
{
	COStore *s = SetUpStore();

	ETUUID *o1 = [ETUUID UUID];
	
	UKNil([s currentCommitForObjectUUID:o1 onBranch:nil]);	
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];
	[s setValue: @"bob"
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];
	UKNotNil(c1);
	UKNotNil([s currentCommitForObjectUUID:o1 onBranch:nil]);
	UKObjectsEqual(c1, [s commitForUUID: [s currentCommitForObjectUUID:o1 onBranch:nil]]);
	UKObjectsEqual(c1, [s commitForUUID: [s tipForObjectUUID:o1 onBranch:nil]]);
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];
	[s setValue: @"bob"
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];	
	[s finishChangesForObject: o1];
	COCommit *c2 = [s finishCommit];
	UKNotNil(c2);
	UKObjectsEqual(c2, [s commitForUUID: [s currentCommitForObjectUUID:o1 onBranch:nil]]);
	UKObjectsEqual(c2, [s commitForUUID: [s tipForObjectUUID:o1 onBranch:nil]]);
	TearDownStore(s);
}

- (void)testStoreNil
{
	COStore *s = SetUpStore();
	
	ETUUID *o1 = [ETUUID UUID];
	
	[s beginCommitWithMetadata: nil];
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];
	[s setValue: nil
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: NO];
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];

	UKNotNil(c1);
	
	TearDownStore(s);
}

@end
