/*
	Copyright (C) 2014 Eric Wasylishen
 
	Date:  December 2013
	License:  MIT  (see COPYING)
 */

// NOTE: This allows to skip compiling all Tests/Model/Extras until all other tests pass on GNUstep.
#ifndef GNUSTEP

#import "TestAttributedStringCommon.h"

@interface TestDiffManager : EditingContextTestCase <UKTest>
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
//    |   |
//    |   \-attributedString2 ("hello world")
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
//    |   |
//    |   \-attributedString2 ("hello world")
//    |
//     \-child2
//        |
//        \-attributedString ("_this **isn't** a big test_")
//
- (void) testAttributedStringAndItemGraphMerge
{
	ETUUID *parentUUID = nil, *child1UUID = nil, *child2UUID = nil, *attributedStringUUID = nil, *attributedString2UUID = nil;
	
	COObjectGraphContext *base = [COObjectGraphContext new];
	{
		UnorderedGroupNoOpposite *parent = [[UnorderedGroupNoOpposite alloc] initWithObjectGraphContext: base];
		UnorderedGroupNoOpposite *child1 = [[UnorderedGroupNoOpposite alloc] initWithObjectGraphContext: base];
		UnorderedGroupNoOpposite *child2 = [[UnorderedGroupNoOpposite alloc] initWithObjectGraphContext: base];
		COAttributedString *attributedString = [[COAttributedString alloc] initWithObjectGraphContext: base];
		base.rootObject = parent;
		parent.contents = S(child1, child2);
		child1.contents = S(attributedString);
		
		[self appendString: @"this is a test" htmlCode: nil toAttributedString: attributedString];

		parentUUID = parent.UUID;
		child1UUID = child1.UUID;
		child2UUID = child2.UUID;
		attributedStringUUID = attributedString.UUID;
	}
	
	COObjectGraphContext *branchA = [COObjectGraphContext new];
	{
		[branchA setItemGraph: base];
		
		UnorderedGroupNoOpposite *child1 = [branchA loadedObjectForUUID: child1UUID];
		UnorderedGroupNoOpposite *child2 = [branchA loadedObjectForUUID: child2UUID];
		COAttributedString *attributedString = [branchA loadedObjectForUUID: attributedStringUUID];
		COAttributedString *attributedString2 = [[COAttributedString alloc] initWithObjectGraphContext: branchA];

		child1.contents = S(attributedString2);
		child2.contents = S(attributedString);

		attributedString.chunks = @[];
		[self appendString: @"this is a big test" htmlCode: @"i" toAttributedString: attributedString];
		
		[self appendString: @"hello world" htmlCode: nil toAttributedString: attributedString2];
	
		attributedString2UUID = attributedString2.UUID;
	}
	
	COObjectGraphContext *branchB = [COObjectGraphContext new];
	{
		[branchB setItemGraph: base];
		
		COAttributedString *attributedString = [branchB loadedObjectForUUID: attributedStringUUID];
		
		attributedString.chunks = @[];
		[self appendString: @"this " htmlCode: nil toAttributedString: attributedString];
		[self appendString: @"isn't" htmlCode: @"b" toAttributedString: attributedString];
		[self appendString: @" a test" htmlCode: nil toAttributedString: attributedString];
	}
	
	CODiffManager *diffBaseBranchA = [CODiffManager diffItemGraph: base withItemGraph: branchA modelDescriptionRepository: base.modelDescriptionRepository sourceIdentifier: @"branchA"];
	CODiffManager *diffBaseBranchB = [CODiffManager diffItemGraph: base withItemGraph: branchB modelDescriptionRepository: base.modelDescriptionRepository sourceIdentifier: @"branchB"];
	
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
		COAttributedString *attributedString2 = [applied loadedObjectForUUID: attributedString2UUID];
		
		UKObjectsSame(parent, applied.rootObject);
		UKObjectsEqual(S(child1, child2), parent.contents);
		UKObjectsEqual(S(attributedString2), child1.contents);
		UKObjectsEqual(S(attributedString), child2.contents);
		
		// Check the attributed string contents

		COAttributedStringWrapper *w1 = [[COAttributedStringWrapper alloc] initWithBacking: attributedString];
		UKObjectsEqual(@"this isn't a big test", w1.string);
		
		[self checkFontHasTraits: NSFontItalicTrait withLongestEffectiveRange: NSMakeRange(0, 5) inAttributedString: w1];
		// This may not be exactly what we want. the bold "n't" did not pick up the italics
		[self checkFontHasTraits: NSFontItalicTrait | NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(5, 2) inAttributedString: w1];
		[self checkFontHasTraits: NSFontBoldTrait withLongestEffectiveRange: NSMakeRange(7, 3) inAttributedString: w1];
		[self checkFontHasTraits: NSFontItalicTrait withLongestEffectiveRange: NSMakeRange(10, 11) inAttributedString: w1];
		
		COAttributedStringWrapper *w2 = [[COAttributedStringWrapper alloc] initWithBacking: attributedString2];
		UKObjectsEqual(@"hello world", w2.string);
	}
}

@end

#endif
