#import "TestStore.h"
#import "COStore.h"

@implementation TestStore

static COStore *SetUpStore()
{
	NSURL *url = [NSURL fileURLWithPath: [@"~/TestStore.sqlitedb" stringByExpandingTildeInPath]];
	
	if([[NSFileManager defaultManager] fileExistsAtPath: [url path]])
	{
		BOOL removed = [[NSFileManager defaultManager] removeItemAtPath: [url path] error: NULL];
		assert(removed);
	}
	
	return [[COStore alloc] initWithURL: url];
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
	
	[s beginChangesForObject: o1
			   onNamedBranch: nil
		   updateObjectState: YES
				parentCommit: nil
				mergedCommit: nil];
	[s setValue: @"ALL YOUR BASE ARE BELONG TO US"
	forProperty: @"name"
	   ofObject: o1
	shouldIndex: YES];
	
	[s finishChangesForObject: o1];
	COCommit *c1 = [s finishCommit];

	NSArray *searchResults = [s resultDictionariesForQuery: @"belo*"];
	UKIntsEqual(1, [searchResults count]);
	if ([searchResults count] == 1)
	{
		NSDictionary *result = [searchResults objectAtIndex: 0];
		UKObjectsEqual(@"name", [result objectForKey: @"property"]);
		UKObjectsEqual([c1 UUID], [result objectForKey: @"commitUUID"]);
		UKObjectsEqual(o1, [result objectForKey: @"objectUUID"]);
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
	UKObjectsEqual(c1, [s currentCommitForObjectUUID:o1 onBranch:nil]);
	UKObjectsEqual(c1, [s tipForObjectUUID:o1 onBranch:nil]);
	
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
	UKObjectsEqual(c2, [s currentCommitForObjectUUID:o1 onBranch:nil]);
	UKObjectsEqual(c2, [s tipForObjectUUID:o1 onBranch:nil]);
	TearDownStore(s);
}

@end
