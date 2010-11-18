#import "TestStore.h"
#import "COStore.h"

@implementation TestStore

static COStore *SetUpStore()
{
	NSURL *url = [NSURL fileURLWithPath: [@"~/TestStore" stringByExpandingTildeInPath]];
	
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
	
	UKObjectsEqual([s namedBranchForUUID: [b UUID]], b);
	
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

@end
