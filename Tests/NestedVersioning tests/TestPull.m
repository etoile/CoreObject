#import "TestCommon.h"

@interface TestPull : NSObject <UKTest> {
	
}

@end

@implementation TestPull

- (void) testPullSimpleFastForward
{
	// setup a simple persistent root containing { "color" : "red" }
	
	COStore *store = setupStore();
	
	COPersistentRootEditingContext *ctx = [store rootContext];
	COSubtree *iroot = [COSubtree subtree];
	
	[ctx setPersistentRootTree: iroot];
	
	
	COSubtree *contents1 = [COSubtree subtree];
	[contents1 setPrimitiveValue: @"red"
					forAttribute: @"color"
							type: kCOStringType];
	
	COSubtree *i1 = [[COSubtreeFactory factory] createPersistentRootWithRootItem: contents1
																	 displayName: @"My Document"
																		   store: store];
	
	// set up a second branch, branch B.
	
	COSubtree *u1BranchA = [[COSubtreeFactory factory] currentBranchOfPersistentRoot: i1];
	COSubtree *u1BranchB = [[COSubtreeFactory factory] createBranchOfPersistentRoot: i1];
	[u1BranchA setPrimitiveValue: @"Branch A" forAttribute: @"name" type: kCOStringType];
	[u1BranchB setPrimitiveValue: @"Branch B" forAttribute: @"name" type: kCOStringType];
	
	
	[iroot addTree: i1];
	
	[ctx commitWithMetadata: nil];
	
	
	// make a commit in the persistent root (which is on branch A) { "color" : "orange" }
	
	{
		COPersistentRootEditingContext *ctx2 = [ctx editingContextForEditingEmbdeddedPersistentRoot: i1];
		COSubtree *contents2 = [ctx2 persistentRootTree];
		[contents2 setPrimitiveValue: @"orange"
						forAttribute: @"color"
								type: kCOStringType];
		
		[ctx2 commitWithMetadata: nil];
	}
	
	// make a commit in the persistent root (which is on branch A) { "color" : "yellow" }
	
	{
		COPersistentRootEditingContext *ctx3 = [ctx editingContextForEditingEmbdeddedPersistentRoot: i1];
		COSubtree *contents3 = [ctx3 persistentRootTree];
		[contents3 setPrimitiveValue: @"yellow"
						forAttribute: @"color"
								type: kCOStringType];
		[ctx3 commitWithMetadata: nil];
	}
	
		
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary
	
	ctx = [store rootContext];
	i1 = [[ctx persistentRootTree] subtreeWithUUID: [i1 UUID]];
	u1BranchA = [[ctx persistentRootTree] subtreeWithUUID: [u1BranchA UUID]];
	u1BranchB = [[ctx persistentRootTree] subtreeWithUUID: [u1BranchB UUID]];
		
	
	// test that we can read the document contents as expected.
	
	UKStringsEqual(@"yellow", [[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchA] persistentRootTree] valueForAttribute: @"color"]);
	UKStringsEqual(@"red", [[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchB] persistentRootTree] valueForAttribute: @"color"]);	
	
	
	// now, suppose we want to pull the changes made in branch A into branch B.
	// this will be a simple fast-forward merge.
	
	[[COSubtreeFactory factory] pullChangesFromBranch: u1BranchA
											 toBranch: u1BranchB
												store: store];
	
	[ctx commitWithMetadata: nil];
	
	UKStringsEqual(@"yellow", [[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchB] persistentRootTree] valueForAttribute: @"color"]);	
}






// Helper functions for testPullComplex()

/**
 * { "letters" : ("b", "c", "d") }
 */
static COSubtree *subtreeInitialVersion(COUUID *aUUID) 
{
	COSubtree *tree = [[[COSubtree alloc] initWithUUID: aUUID] autorelease];
	
	[tree setValue: A(@"b", @"c", @"d")
	  forAttribute: @"letters"
			  type: kCOStringType | kCOArrayType];
	
	return tree;
}

/**
 * { "letters" : ("a", "b", "c", "d") }
 */
static COSubtree *subtreeVariantA(COUUID *aUUID)
{
	COSubtree *tree = subtreeInitialVersion(aUUID);
		
	[tree addObject: @"a"
 toOrderedAttribute: @"letters"
			atIndex: 0
			   type: kCOStringType | kCOArrayType];
		
	return tree;
}

/**
 * { "letters" : ("b", "c", "d", "e") }
 */
static COSubtree *subtreeVariantB(COUUID *aUUID)
{
	COSubtree *tree = subtreeInitialVersion(aUUID);
	
	[tree addObject: @"e"
 toOrderedAttribute: @"letters"
			atIndex: 3
			   type: kCOStringType | kCOArrayType];
	
	return tree;
}







- (void) testPullWithMerge
{
	COStore *store = setupStore();
	
	COPersistentRootEditingContext *ctx = [store rootContext];
	COSubtree *iroot = [COSubtree subtree];
	
	[ctx setPersistentRootTree: iroot];
	
	COUUID *contentsUUID = [COUUID UUID];
	
	COSubtree *i1 = [[COSubtreeFactory factory] createPersistentRootWithRootItem: subtreeInitialVersion(contentsUUID)
																	 displayName: @"My Document"
																		   store: store];
	
	// set up a second branch, branch B.
	
	COSubtree *u1BranchA = [[COSubtreeFactory factory] currentBranchOfPersistentRoot: i1];
	COSubtree *u1BranchB = [[COSubtreeFactory factory] createBranchOfPersistentRoot: i1];
	[u1BranchA setPrimitiveValue: @"Branch A" forAttribute: @"name" type: kCOStringType];
	[u1BranchB setPrimitiveValue: @"Branch B" forAttribute: @"name" type: kCOStringType];
	
	
	[iroot addTree: i1];
	
	[ctx commitWithMetadata: nil];
	
	
	// make a commit on branch A
	
	{
		COPersistentRootEditingContext *ctx2 = [ctx editingContextForEditingEmbdeddedPersistentRoot: i1];
		[ctx2 setPersistentRootTree: subtreeVariantA(contentsUUID)];
		[ctx2 commitWithMetadata: nil];
	}
	
	
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary
	
	ctx = [store rootContext];
	i1 = [[ctx persistentRootTree] subtreeWithUUID: [i1 UUID]];
	u1BranchA = [[ctx persistentRootTree] subtreeWithUUID: [u1BranchA UUID]];
	u1BranchB = [[ctx persistentRootTree] subtreeWithUUID: [u1BranchB UUID]];
	

	// test that we can read the document contents as expected.
	
	UKObjectsEqual(A(@"a", @"b", @"c", @"d"),
				[[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchA] persistentRootTree] valueForAttribute: @"letters"]);
	UKObjectsEqual(A(@"b", @"c", @"d"),
				[[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchB] persistentRootTree] valueForAttribute: @"letters"]);
	
	
	
	// switch to Branch B
	
	[[COSubtreeFactory factory] setCurrentBranch:u1BranchB forPersistentRoot:i1];
	[ctx commitWithMetadata: nil];
	

	// make a commit on branch B
	
	{
		COPersistentRootEditingContext *ctx2 = [ctx editingContextForEditingEmbdeddedPersistentRoot: i1];
		[ctx2 setPersistentRootTree: subtreeVariantB(contentsUUID)];
		[ctx2 commitWithMetadata: nil];
	}
	
	
	
	
	
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary
	
	ctx = [store rootContext];
	i1 = [[ctx persistentRootTree] subtreeWithUUID: [i1 UUID]];
	u1BranchA = [[ctx persistentRootTree] subtreeWithUUID: [u1BranchA UUID]];
	u1BranchB = [[ctx persistentRootTree] subtreeWithUUID: [u1BranchB UUID]];
	
	
	
	
	// test that we can read the document contents as expected.
	
	UKObjectsEqual(A(@"a", @"b", @"c", @"d"),
				[[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchA] persistentRootTree] valueForAttribute: @"letters"]);
	UKObjectsEqual(A(@"b", @"c", @"d", @"e"),
				[[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchB] persistentRootTree] valueForAttribute: @"letters"]);
	

	
	
	
	// now, suppose we want to pull the changes made in branch A into branch B.
	// this will be a full merge.
	
	[[COSubtreeFactory factory] pullChangesFromBranch: u1BranchA
											 toBranch: u1BranchB
												store: store];
	
	[ctx commitWithMetadata: nil];
	
	
	UKObjectsEqual(A(@"a", @"b", @"c", @"d", @"e"),
				[[[ctx editingContextForEditingBranchOfPersistentRoot: u1BranchB] persistentRootTree] valueForAttribute: @"letters"]);
}






- (void) testPullWithNestedPersistentRootMerge
{
	COStore *store = setupStore();
	COUUID *innerContentsUUID = [COUUID UUID];
	
	COSubtree *innerdoc = [[COSubtreeFactory factory] createPersistentRootWithRootItem: subtreeInitialVersion(innerContentsUUID)
																		   displayName: @"My Inner Document"
																				 store: store];

	COSubtree *innerdocBranchA = [[COSubtreeFactory factory] currentBranchOfPersistentRoot: innerdoc];
	
	COSubtree *outerdoc = [[COSubtreeFactory factory] createPersistentRootWithRootItem: innerdoc
																		   displayName: @"My Outer Document"
																				 store: store];

	COSubtree *outerdocBranchA = [[COSubtreeFactory factory] currentBranchOfPersistentRoot: outerdoc];
	COSubtree *outerdocBranchB = [[COSubtreeFactory factory] createBranchOfPersistentRoot: outerdoc];
	
	// Set outerdoc as the store root.
	
	COPersistentRootEditingContext *ctx = [store rootContext];
	[ctx setPersistentRootTree: outerdoc];
	[ctx commitWithMetadata: nil];
	
	
	
	// make a commit on outerdocBranchA/innerdocBranchA
	
	{
		COPath *path = [[COPath pathWithPathComponent: [outerdocBranchA UUID]]
							pathByAppendingPathComponent: [innerdocBranchA UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];
		[ctx2 setPersistentRootTree: subtreeVariantA(innerContentsUUID)];
		[ctx2 commitWithMetadata: nil];
	}
	
	// make a commit on outerdocBranchB/innerdocBranchA
	
	{
		COPath *path = [[COPath pathWithPathComponent: [outerdocBranchB UUID]]
						pathByAppendingPathComponent: [innerdocBranchA UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];
		[ctx2 setPersistentRootTree: subtreeVariantB(innerContentsUUID)];
		[ctx2 commitWithMetadata: nil];
	}
	
	// reopen the context to avoid a merge.
	// FIXME: shouldn't be necessary
	
	ctx = [store rootContext];
	outerdoc = [[ctx persistentRootTree] subtreeWithUUID: [outerdoc UUID]];
	outerdocBranchA = [[ctx persistentRootTree] subtreeWithUUID: [outerdocBranchA UUID]];	
	outerdocBranchB = [[ctx persistentRootTree] subtreeWithUUID: [outerdocBranchB UUID]];
	
		
	// now, suppose we want to pull the changes made in branch A into branch B.
	// this will be a full merge.
	
	[[COSubtreeFactory factory] pullChangesFromBranch: outerdocBranchA
											 toBranch: outerdocBranchB
												store: store];
	
	[ctx commitWithMetadata: nil];
	
	
	
	// check contents of outerdocBranchB/innerdocBranchA
	
	{
		COPath *path = [[COPath pathWithPathComponent: [outerdocBranchB UUID]]
						pathByAppendingPathComponent: [innerdocBranchA UUID]];
		COPersistentRootEditingContext *ctx2 = [COPersistentRootEditingContext editingContextForEditingPath: path
																									inStore: store];
		UKObjectsEqual(A(@"a", @"b", @"c", @"d", @"e"),
					[[ctx2 persistentRootTree] valueForAttribute: @"letters"]);
	}
}

@end
