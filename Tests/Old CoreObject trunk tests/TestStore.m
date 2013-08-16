#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>
#import "TestCommon.h"

@interface TestStore : TestCommon <UKTest>
@end

@implementation TestStore

- (void)testFullTextSearch
{
	ETUUID *rootUUID = [ETUUID UUID];
	ETUUID *trackUUID = [ETUUID UUID];
	ETUUID *o1 = [ETUUID UUID];

	[store insertPersistentRootUUID: rootUUID
	                commitTrackUUID: trackUUID
					 rootObjectUUID: o1];
	
	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: nil];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"cats" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c1 = [store finishCommit];

	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: c1];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"dogs" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c2 = [store finishCommit];
	
	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: c2];
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"horses" forProperty: @"name" ofObject: o1 shouldIndex: YES];
	[store finishChangesForObjectUUID: o1];
	CORevision *c3 = [store finishCommit];
	
	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: c3];
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

- (void)testRootObject
{
	ETUUID *rootUUID = [ETUUID UUID];
	ETUUID *trackUUID = [ETUUID UUID];
	ETUUID *o1 = [ETUUID UUID];
	ETUUID *o2 = [ETUUID UUID];
	ETUUID *o3 = [ETUUID UUID];

	[store insertPersistentRootUUID: rootUUID
	                commitTrackUUID: trackUUID
					 rootObjectUUID: o1];

	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: nil];

	[store beginChangesForObjectUUID: o1];
	[store setValue: @"birds" forProperty: @"name" ofObject: o1 shouldIndex: NO];
	[store finishChangesForObjectUUID: o1];

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
	UKObjectsEqual(S(o1, o2, o3), [store objectUUIDsForCommitTrackUUID: trackUUID]);
	UKObjectsEqual(o1, [store rootObjectUUIDForObjectUUID: o1]);
	UKObjectsEqual(o1, [store rootObjectUUIDForObjectUUID: o2]);
	UKObjectsEqual(o1, [store rootObjectUUIDForObjectUUID: o3]);
}

- (void)testBranch
{
	ETUUID *rootUUID = [ETUUID UUID];
	ETUUID *trackUUID = [ETUUID UUID];
	ETUUID *o1 = [ETUUID UUID];
	ETUUID *o2 = [ETUUID UUID];
	ETUUID *o3 = [ETUUID UUID];
	
	[store insertPersistentRootUUID: rootUUID
	                commitTrackUUID: trackUUID
					 rootObjectUUID: o1];

	/* First revision in main track */
	
	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: nil];
	
	[store beginChangesForObjectUUID: o1];
	[store setValue: @"birds" forProperty: @"name" ofObject: o1 shouldIndex: NO];
	[store finishChangesForObjectUUID: o1];

	CORevision *c1 = [store finishCommit];
	
	/* Second revision in main track */

	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: trackUUID
	                  baseRevision: c1];

	[store beginChangesForObjectUUID: o2];
	[store setValue: @"cats" forProperty: @"name" ofObject: o2 shouldIndex: NO];
	[store finishChangesForObjectUUID: o2];

	CORevision *c2 = [store finishCommit];
	
	/* Third Revision in store structure track (new branch) */

	ETUUID *branchUUID = [ETUUID UUID];

	CORevision *c3 = [store createCommitTrackWithUUID: branchUUID
								                 name: @"Test"
					                   parentRevision: c1
					                   rootObjectUUID: o1
				                   persistentRootUUID: rootUUID
				                  isNewPersistentRoot: NO];

	UKObjectsEqual(c3, [store currentRevisionForTrackUUID: [store UUID]]);
	
	UKTrue([store isTrackUUID: trackUUID]);
	// FIXME: UKTrue([store isTrackUUID: branchUUID]);
	UKObjectsEqual(c2, [store currentRevisionForTrackUUID: trackUUID]);
	UKObjectsEqual(c1, [store currentRevisionForTrackUUID: branchUUID]);
	UKNil([store parentRevisionForCommitTrackUUID: trackUUID]);
	UKObjectsEqual(c1, [store parentRevisionForCommitTrackUUID: branchUUID]);
	UKObjectsEqual(rootUUID, [store persistentRootUUIDForCommitTrackUUID: trackUUID]);
	UKObjectsEqual(rootUUID, [store persistentRootUUIDForCommitTrackUUID: branchUUID]);

	UKObjectsEqual(S(o1, o2), [store objectUUIDsForCommitTrackUUID: trackUUID]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: branchUUID]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: trackUUID atRevision: c1]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: branchUUID atRevision: c1]);
	UKObjectsEqual(S(o1, o2), [store objectUUIDsForCommitTrackUUID: trackUUID atRevision: c2]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: branchUUID atRevision: c2]);

	/* Fourth revision in branch */

	[store beginCommitWithMetadata: nil
	            persistentRootUUID: rootUUID
	               commitTrackUUID: branchUUID
	                  baseRevision: c1];

	[store beginChangesForObjectUUID: o2];
	[store setValue: @"dogs" forProperty: @"name" ofObject: o2 shouldIndex: NO];
	[store finishChangesForObjectUUID: o2];

	[store beginChangesForObjectUUID: o3];
	[store setValue: @"mammals" forProperty: @"name" ofObject: o3 shouldIndex: NO];
	[store finishChangesForObjectUUID: o3];

	CORevision *c4 = [store finishCommit];
								 
	UKObjectsEqual(c2, [store currentRevisionForTrackUUID: trackUUID]);
	UKObjectsEqual(c4, [store currentRevisionForTrackUUID: branchUUID]);
	UKObjectsEqual(S(o1, o2), [store objectUUIDsForCommitTrackUUID: trackUUID]);
	UKObjectsEqual(S(o1, o2, o3), [store objectUUIDsForCommitTrackUUID: branchUUID]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: trackUUID atRevision: c1]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: branchUUID atRevision: c1]);
	UKObjectsEqual(S(o1, o2), [store objectUUIDsForCommitTrackUUID: trackUUID atRevision: c2]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: branchUUID atRevision: c2]);
	UKObjectsEqual(S(o1, o2), [store objectUUIDsForCommitTrackUUID: trackUUID atRevision: c3]);
	UKObjectsEqual(S(o1), [store objectUUIDsForCommitTrackUUID: branchUUID atRevision: c3]);
	UKObjectsEqual(S(o1, o2), [store objectUUIDsForCommitTrackUUID: trackUUID atRevision: c4]);
	UKObjectsEqual(S(o1, o2, o3), [store objectUUIDsForCommitTrackUUID: branchUUID atRevision: c4]);
	
	/* First revision state (main track and branch) */

	UKStringsEqual(@"birds", [[c1 allValuesAndPropertiesForObjectUUID: o1] objectForKey: @"name"]);
	UKNil([[c1 allValuesAndPropertiesForObjectUUID: o2] objectForKey: @"name"]);
	UKNil([[c1 allValuesAndPropertiesForObjectUUID: o3] objectForKey: @"name"]);
	
	/* Second revision state (main track) */ 

	UKStringsEqual(@"birds", [[c2 allValuesAndPropertiesForObjectUUID: o1] objectForKey: @"name"]);
	UKStringsEqual(@"cats", [[c2 allValuesAndPropertiesForObjectUUID: o2] objectForKey: @"name"]);
	UKNil([[c2 allValuesAndPropertiesForObjectUUID: o3] objectForKey: @"name"]);
	 
	/* Third revision state (store structure track) */

	UKStringsEqual(@"birds", [[c3 allValuesAndPropertiesForObjectUUID: o1] objectForKey: @"name"]);
	UKNil([[c3 allValuesAndPropertiesForObjectUUID: o2] objectForKey: @"name"]);
	UKNil([[c3 allValuesAndPropertiesForObjectUUID: o3] objectForKey: @"name"]);

	/* Fourth revision state (branch) */
	
	UKStringsEqual(@"birds", [[c4 allValuesAndPropertiesForObjectUUID: o1] objectForKey: @"name"]);
	UKStringsEqual(@"dogs", [[c4 allValuesAndPropertiesForObjectUUID: o2] objectForKey: @"name"]);
	UKStringsEqual(@"mammals", [[c4 allValuesAndPropertiesForObjectUUID: o3] objectForKey: @"name"]);
}

@end
