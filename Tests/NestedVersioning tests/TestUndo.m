#import "TestCommon.h"

@interface TestUndo : NSObject <UKTest> {
	
}

@end

@implementation TestUndo


- (void) testSelectiveUndoWithNestedPersistentRootMerge
{
	COStore *store = setupStore();
	COSubtree *innerdoc;
	COSubtree *middledoc;
	COSubtree *outerdoc;	
	
	{
		COSubtree *tree = [COSubtree subtree];
		[tree setValue: A(@"a", @"c", @"d")
		  forAttribute: @"letters"
				  type: kCOStringType | kCOArrayType];
		
		innerdoc = [[COSubtreeFactory factory] createPersistentRootWithRootItem: tree
																	displayName: @"My Inner Document"
																		  store: store];
	}
	
	middledoc = [[COSubtreeFactory factory] createPersistentRootWithRootItem: innerdoc
																displayName: @"My Middle Document"
																	  store: store];

	outerdoc = [[COSubtreeFactory factory] createPersistentRootWithRootItem: middledoc
																displayName: @"My Outer Document"
																	  store: store];
	
	
	// Set outerdoc as the store root.
	
	COPersistentRootEditingContext *ctx = [store rootContext];
	[ctx setPersistentRootTree: outerdoc];
	[ctx commitWithMetadata: nil];
	
	COUUID *state0 = [[COSubtreeFactory factory] currentVersionForBranchOrPersistentRoot: outerdoc]; // { "a", "c", "d" }
	
	
	// make a commit on innerdoc
	
	{
		COPath *path = [[[COPath pathWithPathComponent: [outerdoc UUID]]
						  pathByAppendingPathComponent: [middledoc UUID]]
						pathByAppendingPathComponent: [innerdoc UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];	
		COSubtree *tree = [ctx2 persistentRootTree];
		tree addObject: @"b" toOrderedAttribute: @"letters" atIndex: 1 type: [kCOStringType | kCOArrayType];		
		[ctx2 commitWithMetadata: nil];
	}

	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary	
	ctx = [store rootContext];
	outerdoc = [ctx persistentRootTree];
	
	COUUID *state1 = [[COSubtreeFactory factory] currentVersionForBranchOrPersistentRoot: outerdoc]; // { "a", "b", "c", "d" }
	
	// make a commit on innerdoc
	
	{
		COPath *path = [[[COPath pathWithPathComponent: [outerdoc UUID]]
						 pathByAppendingPathComponent: [middledoc UUID]]
						pathByAppendingPathComponent: [innerdoc UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];	
		COSubtree *tree = [ctx2 persistentRootTree];
		tree addObject: @"e" toOrderedAttribute: @"letters" atIndex: 4 type: [kCOStringType | kCOArrayType];		
		[ctx2 commitWithMetadata: nil];
	}
	
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary	
	ctx = [store rootContext];
	outerdoc = [ctx persistentRootTree];
	
	COUUID *state2 = [[COSubtreeFactory factory] currentVersionForBranchOrPersistentRoot: outerdoc]; // { "a", "b", "c", "d", "e" }	
	
	// check contents
		
	{
		COPath *path = [[[COPath pathWithPathComponent: [outerdoc UUID]]
						 pathByAppendingPathComponent: [middledoc UUID]]
						pathByAppendingPathComponent: [innerdoc UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];
		UKObjectsEqual(A(@"a", @"b", @"c", @"d", @"e"),
					   [[ctx2 persistentRootTree] valueForAttribute: @"letters"]);
	}
	
	// check commits
	
	UKNotNil(state0);
	UKNotNil(state1);
	UKNotNil(state2);
	UKNil([store parentForCommit: state0]);
	UKObjectsEqual(state0, [store parentForCommit: state1]);
	UKObjectsEqual(state1, [store parentForCommit: state2]);
	
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary
	
	ctx = [store rootContext];
	
	COPersistentRootDiff *diff = [[COSubtreeFactory factory] selectiveUndoCommit: state1
																forCommit: state2
																	store: store];
	UKNotNil(diff);
	UKFalse([diff hasConflicts]);
	
	if (diff != nil && ![diff hasConflicts])
	{
		COUUID *result = [diff commitInStore: store];
		outerdoc = [ctx persistentRootTree];
		[[COSubtreeFactory factory] setCurrentVersion: result
							forBranchOrPersistentRoot: outerdoc
												store: store];
		[ctx commitWithMetadata: nil];
	}
	
	// check contents
	
	{
		COPath *path = [[[COPath pathWithPathComponent: [outerdoc UUID]]
						 pathByAppendingPathComponent: [middledoc UUID]]
						pathByAppendingPathComponent: [innerdoc UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];
		UKObjectsEqual(A(@"a", @"c", @"d", @"e"),
					   [[ctx2 persistentRootTree] valueForAttribute: @"letters"]);
	}
}


@end
