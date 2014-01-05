/*
	Copyright (C) 2013 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import "TestAttributedStringCommon.h"

@interface TestDiffManager : TestAttributedStringCommon <UKTest>
@end

@implementation TestDiffManager

// base:
//
//   parent
//    |
//    |\-child1
//    |   |
//    |   \-attributedString ("this is a test")
//    |
//     \-child2
//
//
// branchA:
//
//
//   parent
//    |
//    |\-child1
//    |
//     \-child2
//        |
//        \-attributedString ("_this is a big test_")
//
//
// branchB:
//
//   parent
//    |
//    |\-child1
//    |   |
//    |   \-attributedString ("this **isn't** a test")
//    |
//     \-child2
//
//
// expected merge (branchA + branchB):
//
//   parent
//    |
//    |\-child1
//    |
//     \-child2
//        |
//        \-attributedString ("_this **isn't** a big test_")
//
- (void) testAttributedStringAndItemGraphMerge
{
#if 0
	ETUUID *parentUUID = nil, *child1UUID = nil, *child2UUID = nil, *attributedStringUUID = nil;
	
	COObjectGraphContext *base = [COObjectGraphContext new];
	{
		UnorderedGroupNoOpposite *parent = [[UnorderedGroupNoOpposite alloc] initWithObjectGraphContext: base];
		UnorderedGroupNoOpposite *child1 = [[UnorderedGroupNoOpposite alloc] initWithObjectGraphContext: base];
		UnorderedGroupNoOpposite *child2 = [[UnorderedGroupNoOpposite alloc] initWithObjectGraphContext: base];
		COAttributedString *attributedString = [[COAttributedString alloc] initWithObjectGraphContext: base];
		base.rootObject = parent;
		parent.contents = S(child1, child2);
		child1.contents = S(attributedString);
		
		parentUUID = parent.UUID;
		child1UUID = child1.UUID;
		child2UUID = child2.UUID;
		attributedStringUUID = attributedString.UUID;
		
		[self appendString: @"this is a test" htmlCode: nil toAttributedString: attributedString];
	}
	
	COObjectGraphContext *branchA = [COObjectGraphContext new];
	{
		[branchA setItemGraph: base];
		
		UnorderedGroupNoOpposite *child1 = [branchA loadedObjectForUUID: child1UUID];
		UnorderedGroupNoOpposite *child2 = [branchA loadedObjectForUUID: child2UUID];
		COAttributedString *attributedString = [branchA loadedObjectForUUID: attributedStringUUID];

		child1.contents = S();
		child2.contents = S(attributedString);

		attributedString.chunks = @[];
		[self appendString:@"this is a big test" htmlCode: @"i" toAttributedString: attributedString];
	}
	
	COObjectGraphContext *branchB = [COObjectGraphContext new];
	{
		[branchB setItemGraph: base];
		
		COAttributedString *attributedString = [branchB loadedObjectForUUID: attributedStringUUID];
		
		attributedString.chunks = @[];
		[self appendString:@"this " htmlCode: nil toAttributedString: attributedString];
		[self appendString:@"isn't" htmlCode: @"b" toAttributedString: attributedString];
		[self appendString:@" a test" htmlCode: nil toAttributedString: attributedString];
	}
	
	CODiffManager *diffBaseBranchA = [CODiffManager diffItemGraph: base withItemGraph: branchA modelDescriptionRepository: [base modelDescriptionRepository] sourceIdentifier: @"branchA"];
	CODiffManager *diffBaseBranchB = [CODiffManager diffItemGraph: base withItemGraph: branchB modelDescriptionRepository: [base modelDescriptionRepository] sourceIdentifier: @"branchB"];
	
	CODiffManager *merged = [diffBaseBranchA diffByMergingWithDiff: diffBaseBranchB];
	
	COObjectGraphContext *applied = [COObjectGraphContext new];
	[applied setItemGraph: base];
	[merged applyTo: applied];
	
	// Check the merge result
	
	{
		// Check the tree structure
		
		UnorderedGroupNoOpposite *parent = [applied loadedObjectForUUID: parentUUID];
		UnorderedGroupNoOpposite *child1 = [applied loadedObjectForUUID: child1UUID];
		UnorderedGroupNoOpposite *child2 = [applied loadedObjectForUUID: child2UUID];
		COAttributedString *attributedString = [applied loadedObjectForUUID: attributedStringUUID];
		
		UKObjectsSame(parent, [applied rootObject]);
		UKObjectsEqual(S(child1, child2), parent.contents);
		UKObjectsEqual(S(), child1.contents);
		UKObjectsEqual(S(attributedString), child2.contents);
		
		// Check the attributed string contents
		
		UKObjectsEqual(@"this isn't a big test", [attributedString string]);
		UKObjectsEqual(A(@"this ", @"isn't", @" a big test"), [attributedString valueForKeyPath: @"chunks.text"]);
		UKObjectsEqual(A(S(@"i"), S(@"b", @"i"), S(@"i")), [attributedString valueForKeyPath: @"chunks.attributes.htmlCode"]);
	}
#endif
}

@end
